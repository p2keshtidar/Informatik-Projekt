package de.frauas.girokonto.booking;

import de.frauas.girokonto.account.Account;
import de.frauas.girokonto.account.AccountRepository;
import de.frauas.girokonto.account.AccountType;
import de.frauas.girokonto.common.ApiException;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.Instant;
import java.util.Arrays;
import java.util.Collection;
import java.util.HashSet;
import java.util.List;
import java.util.Objects;
import java.util.Optional;
import java.util.Set;

// Zentrale Stelle für jede Geldbewegung (Überweisung, Sparrate, Kreditrate, Startguthaben …).
// Doppelte Buchführung: jede Buchung hat mindestens zwei Zeilen, ihre Summe ist immer 0.
@Service
public class BookingService {

    // Startguthaben für jedes neue Girokonto: 10.000,00 €
    public static final long START_CREDIT_CENTS = 1_000_000L;

    // System-Konto aus V2__system_account.sql, Gegenkonto für das Startguthaben
    public static final String OPENING_ACCOUNT_NAME = "PHD Kontor Startguthaben";

    public static final String OPENING_DESCRIPTION = "Startguthaben";

    private static final int MAX_DESCRIPTION = 140;
    private static final int MAX_KEY = 100;
    private static final int MAX_CATEGORY = 30;

    // Name des UNIQUE-Constraints auf booking.idempotency_key (von PostgreSQL vergeben)
    private static final String KEY_CONSTRAINT = "booking_idempotency_key_key";

    private final BookingRepository bookings;
    private final AccountRepository accounts;
    private final Clock clock;

    public BookingService(BookingRepository bookings, AccountRepository accounts, Clock clock) {
        this.bookings = bookings;
        this.accounts = accounts;
        this.clock = clock;
    }

    // Eine Zeile: + Eingang, − Ausgang. category ist optional.
    public record Line(Long accountId, long amountCents, String category) {
        public static Line of(Long accountId, long amountCents) {
            return new Line(accountId, amountCents, null);
        }
    }

    @Transactional
    public Booking book(BookingType type, String description, String idempotencyKey, Long createdBy,
                        Line... lines) {
        return book(type, description, idempotencyKey, createdBy, lines == null ? null : Arrays.asList(lines));
    }

    // Bucht in einer Transaktion. Gleicher idempotencyKey = gleiche Buchung, es wird nichts doppelt gebucht.
    // Prüft keine Deckung: das machen die Aufrufer (erst lockAccounts, dann balanceOf, dann book).
    @Transactional
    public Booking book(BookingType type, String description, String idempotencyKey, Long createdBy,
                        List<Line> lines) {
        validate(type, description, idempotencyKey, lines);

        // Idempotenz: schon gebucht → die vorhandene Buchung zurückgeben
        Optional<Booking> existing = bookings.findByIdempotencyKey(idempotencyKey);
        if (existing.isPresent()) {
            existing.get().getLines().size();   // Zeilen laden, damit sie auch nach der Transaktion lesbar sind
            return existing.get();
        }

        lockAccounts(lines.stream().map(Line::accountId).toList());

        Booking booking = new Booking(type, description, Instant.now(clock), idempotencyKey, createdBy);
        for (Line line : lines) {
            booking.addLine(line.accountId(), line.amountCents(), line.category());
        }
        try {
            bookings.save(booking);
            bookings.flush();
        } catch (DataIntegrityViolationException e) {
            // Zwei Anfragen mit demselben Key gleichzeitig: die zweite scheitert am UNIQUE-Index.
            // Die Transaktion ist in PostgreSQL danach abgebrochen, also hier nicht weitermachen.
            if (isDuplicateKey(e)) {
                throw ApiException.conflict("Diese Buchung wird gerade schon ausgeführt");
            }
            throw e;
        }
        // Der Trigger trg_booking_balanced prüft die Summe zusätzlich beim Commit (zweite Sicherung)
        return booking;
    }

    // Sperrt die Konten bis zum Ende der laufenden Transaktion (SELECT … ORDER BY id FOR UPDATE).
    // Immer nach ID aufsteigend, damit sich zwei Buchungen nicht gegenseitig blockieren (Deadlock).
    // Aufrufer wie der TransferService können so in einer Transaktion sperren, den Saldo prüfen und buchen.
    @Transactional(propagation = Propagation.MANDATORY)
    public void lockAccounts(Collection<Long> accountIds) {
        if (accountIds == null || accountIds.isEmpty() || accountIds.stream().anyMatch(Objects::isNull)) {
            throw ApiException.badRequest("Konto fehlt");
        }
        List<Long> ids = accountIds.stream().distinct().sorted().toList();
        List<Long> locked = accounts.lockByIdsOrderById(ids);
        if (locked.size() != ids.size()) {
            throw ApiException.notFound("Konto nicht gefunden");
        }
    }

    // Startguthaben für ein gerade eröffnetes Girokonto: System-Konto −10.000 €, Girokonto +10.000 €.
    // Der Key "opening-<userId>" sorgt dafür, dass es jeder Nutzer höchstens einmal bekommt.
    @Transactional
    public Booking bookStartCredit(Long userId, Long mainAccountId) {
        Account system = accounts.findFirstByTypeAndName(AccountType.SYSTEM, OPENING_ACCOUNT_NAME)
                .orElseThrow(() -> new IllegalStateException(
                        "System-Konto '" + OPENING_ACCOUNT_NAME + "' fehlt (Migration V2)"));
        return book(BookingType.OPENING, OPENING_DESCRIPTION, "opening-" + userId, null,
                Line.of(system.getId(), -START_CREDIT_CENTS),
                Line.of(mainAccountId, START_CREDIT_CENTS));
    }

    private static void validate(BookingType type, String description, String idempotencyKey, List<Line> lines) {
        if (type == null) {
            throw ApiException.badRequest("Buchungsart fehlt");
        }
        if (description == null || description.isBlank()) {
            throw ApiException.badRequest("Verwendungszweck fehlt");
        }
        if (description.length() > MAX_DESCRIPTION) {
            throw ApiException.badRequest("Verwendungszweck ist zu lang (höchstens " + MAX_DESCRIPTION + " Zeichen)");
        }
        if (idempotencyKey == null || idempotencyKey.isBlank()) {
            throw ApiException.badRequest("Idempotenz-Schlüssel fehlt");
        }
        if (idempotencyKey.length() > MAX_KEY) {
            throw ApiException.badRequest("Idempotenz-Schlüssel ist zu lang (höchstens " + MAX_KEY + " Zeichen)");
        }
        if (lines == null || lines.size() < 2) {
            throw ApiException.badRequest("Eine Buchung braucht mindestens zwei Zeilen");
        }

        long sum = 0;
        Set<Long> accountIds = new HashSet<>();
        for (Line line : lines) {
            if (line == null || line.accountId() == null) {
                throw ApiException.badRequest("Konto fehlt in einer Buchungszeile");
            }
            if (line.amountCents() == 0) {
                throw ApiException.badRequest("Ein Betrag von 0 ist nicht erlaubt");
            }
            if (line.category() != null && line.category().length() > MAX_CATEGORY) {
                throw ApiException.badRequest("Kategorie ist zu lang (höchstens " + MAX_CATEGORY + " Zeichen)");
            }
            try {
                sum = Math.addExact(sum, line.amountCents());
            } catch (ArithmeticException e) {
                throw ApiException.badRequest("Betrag ist zu groß");
            }
            accountIds.add(line.accountId());
        }
        if (sum != 0) {
            throw ApiException.badRequest("Die Buchung ist nicht ausgeglichen (Summe " + sum + " Cent)");
        }
        if (accountIds.size() < 2) {
            throw ApiException.badRequest("Eine Buchung braucht mindestens zwei verschiedene Konten");
        }
    }

    private static boolean isDuplicateKey(DataIntegrityViolationException e) {
        String message = e.getMostSpecificCause().getMessage();
        return message != null && message.contains(KEY_CONSTRAINT);
    }
}
