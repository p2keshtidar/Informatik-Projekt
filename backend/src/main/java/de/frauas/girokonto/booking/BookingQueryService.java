package de.frauas.girokonto.booking;

import de.frauas.girokonto.account.AccountService;
import de.frauas.girokonto.common.ApiException;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;

// Liest Buchungen (nur lesen, bucht nichts). Gebucht wird ausschließlich über den BookingService.
@Service
public class BookingQueryService {

    public static final int DEFAULT_SIZE = 20;
    public static final int MAX_SIZE = 100;

    // "von 01.12. bis 05.12." meint deutsche Kalendertage, gespeichert wird in UTC
    private static final ZoneId ZONE = ZoneId.of("Europe/Berlin");

    // Name der Gegenseite aus Sicht von bl.account_id: alle ANDEREN Zeilen derselben Buchung.
    // Gehört das Konto einem Nutzer → "Vorname Nachname", sonst (System-Konto) der Kontoname.
    private static final String COUNTERPARTY = """
            (SELECT string_agg(COALESCE(u.first_name || ' ' || u.last_name, a.name), ', ' ORDER BY o.id)
               FROM booking_line o
               JOIN account a ON a.id = o.account_id
               LEFT JOIN app_user u ON u.id = a.owner_id
              WHERE o.booking_id = bl.booking_id AND o.account_id <> bl.account_id)""";

    // Alle Zeilen eines Kontos mit Buchungsdaten. Als Unterabfrage, damit man im WHERE auch
    // nach counterparty_name filtern kann.
    private static final String BASE = """
            SELECT * FROM (
                SELECT b.id, b.booked_at, b.type, b.description, bl.amount_cents, bl.category,
                       %s AS counterparty_name
                  FROM booking_line bl
                  JOIN booking b ON b.id = bl.booking_id
                 WHERE bl.account_id = :accountId
            ) x
            """.formatted(COUNTERPARTY);

    private static final RowMapper<BookingItemDto> ITEM = (rs, i) -> new BookingItemDto(
            rs.getLong("id"),
            rs.getTimestamp("booked_at").toInstant(),
            BookingType.valueOf(rs.getString("type")),
            rs.getString("description"),
            rs.getLong("amount_cents"),
            rs.getString("counterparty_name"),
            rs.getString("category"));

    private final NamedParameterJdbcTemplate jdbc;
    private final AccountService accountService;

    public BookingQueryService(NamedParameterJdbcTemplate jdbc, AccountService accountService) {
        this.jdbc = jdbc;
        this.accountService = accountService;
    }

    // Filter für die Umsatzliste. Alles optional (null = kein Filter).
    // from/to: Kalendertage, beide einschließlich. minCents/maxCents: Betrag ohne Vorzeichen.
    // q: Text in Verwendungszweck oder Name der Gegenseite, Groß-/Kleinschreibung egal.
    public record Filter(LocalDate from, LocalDate to, Long minCents, Long maxCents, String q) {
    }

    // Eine Seite der Liste. hasMore = true → die App kann page + 1 nachladen.
    public record Page(List<BookingItemDto> items, int page, int size, long totalItems, boolean hasMore) {
    }

    // Detailansicht einer Buchung mit allen Zeilen
    public record Detail(Long id, Instant bookedAt, BookingType type, String description, List<DetailLine> lines) {
    }

    // own = true: Konto des angemeldeten Nutzers. Fremde IBANs nur maskiert.
    public record DetailLine(String name, String iban, long amountCents, String category, boolean own) {
    }

    // Umsätze eines Kontos, neueste zuerst
    @Transactional(readOnly = true)
    public Page bookingsOf(Long userId, Long accountId, Filter filter, int page, int size) {
        accountService.requireOwnAccount(userId, accountId);
        validate(filter, page, size);

        MapSqlParameterSource params = new MapSqlParameterSource("accountId", accountId);
        StringBuilder where = new StringBuilder(" WHERE 1 = 1");
        if (filter.from() != null) {
            where.append(" AND booked_at >= :from");
            params.addValue("from", java.sql.Timestamp.from(startOfDay(filter.from())));
        }
        if (filter.to() != null) {
            // bis einschließlich "to" = vor dem Beginn des nächsten Tages
            where.append(" AND booked_at < :toExclusive");
            params.addValue("toExclusive", java.sql.Timestamp.from(startOfDay(filter.to().plusDays(1))));
        }
        if (filter.minCents() != null) {
            where.append(" AND ABS(amount_cents) >= :minCents");
            params.addValue("minCents", filter.minCents());
        }
        if (filter.maxCents() != null) {
            where.append(" AND ABS(amount_cents) <= :maxCents");
            params.addValue("maxCents", filter.maxCents());
        }
        if (filter.q() != null && !filter.q().isBlank()) {
            where.append(" AND (description ILIKE :q ESCAPE '\\' OR counterparty_name ILIKE :q ESCAPE '\\')");
            params.addValue("q", "%" + escapeLike(filter.q().trim()) + "%");
        }

        long total = jdbc.queryForObject("SELECT COUNT(*) FROM (" + BASE + where + ") c", params, Long.class);

        params.addValue("limit", size);
        params.addValue("offset", (long) page * size);
        List<BookingItemDto> items = jdbc.query(
                BASE + where + " ORDER BY booked_at DESC, id DESC LIMIT :limit OFFSET :offset", params, ITEM);

        return new Page(items, page, size, total, (long) (page + 1) * size < total);
    }

    // Eine Buchung mit allen Zeilen. Erlaubt, wenn mindestens eine Zeile ein eigenes Konto betrifft.
    @Transactional(readOnly = true)
    public Detail booking(Long userId, Long bookingId) {
        record Row(Long id, Instant bookedAt, BookingType type, String description, String name, String iban,
                   long amountCents, String category, boolean own) {
        }
        List<Row> rows = jdbc.query("""
                        SELECT b.id, b.booked_at, b.type, b.description,
                               COALESCE(u.first_name || ' ' || u.last_name, a.name) AS name,
                               a.iban, bl.amount_cents, bl.category,
                               (a.owner_id = :userId) AS own
                          FROM booking b
                          JOIN booking_line bl ON bl.booking_id = b.id
                          JOIN account a ON a.id = bl.account_id
                          LEFT JOIN app_user u ON u.id = a.owner_id
                         WHERE b.id = :bookingId
                         ORDER BY bl.id
                        """,
                new MapSqlParameterSource("bookingId", bookingId).addValue("userId", userId),
                (rs, i) -> new Row(rs.getLong("id"), rs.getTimestamp("booked_at").toInstant(),
                        BookingType.valueOf(rs.getString("type")), rs.getString("description"),
                        rs.getString("name"), rs.getString("iban"), rs.getLong("amount_cents"),
                        rs.getString("category"), rs.getBoolean("own")));

        if (rows.isEmpty()) {
            throw ApiException.notFound("Buchung nicht gefunden");
        }
        if (rows.stream().noneMatch(Row::own)) {
            throw ApiException.forbidden("Diese Buchung gehört nicht zu deinen Konten");
        }
        Row first = rows.get(0);
        List<DetailLine> lines = rows.stream()
                .map(r -> new DetailLine(r.name(), r.own() ? r.iban() : maskIban(r.iban()), r.amountCents(),
                        r.category(), r.own()))
                .toList();
        return new Detail(first.id(), first.bookedAt(), first.type(), first.description(), lines);
    }

    private static void validate(Filter f, int page, int size) {
        if (page < 0) {
            throw ApiException.badRequest("page darf nicht negativ sein");
        }
        if (size < 1 || size > MAX_SIZE) {
            throw ApiException.badRequest("size muss zwischen 1 und " + MAX_SIZE + " liegen");
        }
        if (f.from() != null && f.to() != null && f.from().isAfter(f.to())) {
            throw ApiException.badRequest("Das Startdatum liegt nach dem Enddatum");
        }
        if ((f.minCents() != null && f.minCents() < 0) || (f.maxCents() != null && f.maxCents() < 0)) {
            throw ApiException.badRequest("Beträge im Filter dürfen nicht negativ sein");
        }
        if (f.minCents() != null && f.maxCents() != null && f.minCents() > f.maxCents()) {
            throw ApiException.badRequest("Der Mindestbetrag ist größer als der Höchstbetrag");
        }
        if (f.q() != null && f.q().length() > 100) {
            throw ApiException.badRequest("Suchtext ist zu lang (höchstens 100 Zeichen)");
        }
    }

    private static Instant startOfDay(LocalDate day) {
        return day.atStartOfDay(ZONE).toInstant();
    }

    // % und _ sind bei LIKE Platzhalter. Wer danach sucht, meint das Zeichen selbst.
    private static String escapeLike(String text) {
        return text.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_");
    }

    // DE89370400440532013000 → DE89 **** 3000 (nur Anfang und Ende sichtbar)
    static String maskIban(String iban) {
        if (iban == null || iban.length() < 8) {
            return iban;
        }
        return iban.substring(0, 4) + " **** " + iban.substring(iban.length() - 4);
    }
}
