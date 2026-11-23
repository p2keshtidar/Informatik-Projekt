package de.frauas.girokonto.booking;

import de.frauas.girokonto.IntegrationTestBase;
import de.frauas.girokonto.account.Account;
import de.frauas.girokonto.account.AccountType;
import de.frauas.girokonto.booking.BookingService.Line;
import de.frauas.girokonto.common.ApiException;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.TestInstance;
import org.junit.jupiter.api.function.Executable;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.dao.DataAccessException;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import org.springframework.transaction.IllegalTransactionStateException;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

import java.util.List;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;

import static de.frauas.girokonto.booking.BookingService.START_CREDIT_CENTS;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertInstanceOf;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

// PER_CLASS, damit @AfterAll die Summe aller Buchungszeilen mit den Spring-Beans prüfen kann
@TestInstance(TestInstance.Lifecycle.PER_CLASS)
class BookingServiceTest extends IntegrationTestBase {

    @Autowired
    private BookingService bookingService;

    @Autowired
    private BookingRepository bookingRepository;

    @Autowired
    private BookingLineRepository lineRepository;

    @Autowired
    private JdbcTemplate jdbc;

    @Autowired
    private PlatformTransactionManager transactionManager;

    // ---------------------------------------------------------------- Pflicht-Tests

    @Test
    void unausgeglicheneBuchungGibt400() throws Exception {
        long[] k = zweiKonten();
        String key = key();

        erwarteFehler(HttpStatus.BAD_REQUEST, () -> bookingService.book(BookingType.INTERNAL, "Test", key, null,
                Line.of(k[0], -100), Line.of(k[1], 99)));
        assertTrue(bookingRepository.findByIdempotencyKey(key).isEmpty());
    }

    @Test
    void triggerLehntUnausgeglicheneBuchungBeimCommitAb() {
        // am Service vorbei direkt in die Datenbank. Der Trigger ist DEFERRED und greift erst beim Commit,
        // deshalb eine eigene Transaktion, die wirklich committet. Der Transaktionsmanager der App (JPA)
        // übersetzt den Fehler beim Commit in eine DataAccessException.
        TransactionTemplate tx = new TransactionTemplate(transactionManager);
        String key = key();
        Long konto = systemKonto();

        DataAccessException e = assertThrows(DataAccessException.class, () -> tx.executeWithoutResult(s -> {
            Long bookingId = jdbc.queryForObject("INSERT INTO booking (type, description, booked_at, idempotency_key) "
                    + "VALUES ('INTERNAL', 'Trigger-Test', now(), ?) RETURNING id", Long.class, key);
            jdbc.update("INSERT INTO booking_line (booking_id, account_id, amount_cents) VALUES (?, ?, 100)",
                    bookingId, konto);
        }));
        assertTrue(e.getMostSpecificCause().getMessage().contains("nicht ausgeglichen"),
                () -> "unerwartete Meldung: " + e.getMostSpecificCause().getMessage());
        assertTrue(bookingRepository.findByIdempotencyKey(key).isEmpty());
    }

    @Test
    void nurEineZeileGibt400() throws Exception {
        long[] k = zweiKonten();

        erwarteFehler(HttpStatus.BAD_REQUEST, () -> bookingService.book(BookingType.INTERNAL, "Test", key(), null,
                Line.of(k[0], 100)));
        erwarteFehler(HttpStatus.BAD_REQUEST, () -> bookingService.book(BookingType.INTERNAL, "Test", key(), null,
                List.of()));
    }

    @Test
    void gleicherKeyZweimalNurEineBuchung() throws Exception {
        long[] k = zweiKonten();
        String key = key();

        Booking erste = bookingService.book(BookingType.INTERNAL, "Umbuchung", key, null,
                Line.of(k[0], -2_500), Line.of(k[1], 2_500));
        Booking zweite = bookingService.book(BookingType.INTERNAL, "Umbuchung", key, null,
                Line.of(k[0], -2_500), Line.of(k[1], 2_500));

        assertEquals(erste.getId(), zweite.getId());
        assertEquals(2, zweite.getLines().size());
        assertEquals(2, lineRepository.findByBookingId(erste.getId()).size());
        assertEquals(START_CREDIT_CENTS - 2_500, accountRepository.balanceOf(k[0]));
        assertEquals(2_500, accountRepository.balanceOf(k[1]));
    }

    @Test
    void nachVerifyEmailIstSaldo10000Euro() throws Exception {
        RegisteredUser user = registerAndVerify();
        Long girokonto = mainAccountId(user.userId());

        assertEquals(1_000_000L, START_CREDIT_CENTS);
        assertEquals(1_000_000L, accountRepository.balanceOf(girokonto));

        // auch über die API: mit Token-Login GET /api/accounts, davor GET /api/users/{id}/accounts
        MockHttpServletRequestBuilder request = user.accessToken() != null
                ? get("/api/accounts").header("Authorization", bearer(user.accessToken()))
                : get("/api/users/{userId}/accounts", user.userId());
        mvc.perform(request)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].type").value("MAIN"))
                .andExpect(jsonPath("$[0].balanceCents").value(1_000_000));
    }

    @Test
    void startguthabenSystemKontoUndGirokontoZusammenNull() throws Exception {
        Long system = systemKonto();
        long systemVorher = accountRepository.balanceOf(system);

        RegisteredUser user = registerAndVerify();

        Booking opening = bookingRepository.findByIdempotencyKey("opening-" + user.userId()).orElseThrow();
        assertEquals(BookingType.OPENING, opening.getType());
        assertEquals("Startguthaben", opening.getDescription());
        assertNull(opening.getCreatedBy());

        List<BookingLine> lines = lineRepository.findByBookingId(opening.getId());
        assertEquals(2, lines.size());
        assertEquals(0, lines.stream().mapToLong(BookingLine::getAmountCents).sum());
        assertEquals(systemVorher - 1_000_000L, accountRepository.balanceOf(system));
    }

    // ---------------------------------------------------------------- weitere Fälle

    @Test
    void startguthabenWirdNurEinmalGebucht() throws Exception {
        RegisteredUser user = registerAndVerify();
        Long girokonto = mainAccountId(user.userId());
        Long ersteId = bookingRepository.findByIdempotencyKey("opening-" + user.userId()).orElseThrow().getId();

        Booking nochmal = bookingService.bookStartCredit(user.userId(), girokonto);

        assertEquals(ersteId, nochmal.getId());
        assertEquals(START_CREDIT_CENTS, accountRepository.balanceOf(girokonto));
    }

    @Test
    void betragNullGibt400() throws Exception {
        long[] k = zweiKonten();

        erwarteFehler(HttpStatus.BAD_REQUEST, () -> bookingService.book(BookingType.INTERNAL, "Test", key(), null,
                Line.of(k[0], 0), Line.of(k[1], 0)));
    }

    @Test
    void zweiZeilenAufDasselbeKontoGibt400() throws Exception {
        long[] k = zweiKonten();

        erwarteFehler(HttpStatus.BAD_REQUEST, () -> bookingService.book(BookingType.INTERNAL, "Test", key(), null,
                Line.of(k[0], -100), Line.of(k[0], 100)));
    }

    @Test
    void unbekanntesKontoGibt404() throws Exception {
        long[] k = zweiKonten();
        String key = key();

        erwarteFehler(HttpStatus.NOT_FOUND, () -> bookingService.book(BookingType.INTERNAL, "Test", key, null,
                Line.of(k[0], -100), Line.of(Long.MAX_VALUE, 100)));
        assertTrue(bookingRepository.findByIdempotencyKey(key).isEmpty());
        assertEquals(START_CREDIT_CENTS, accountRepository.balanceOf(k[0]));
    }

    @Test
    void fehlendeOderZuLangeAngabenGeben400() throws Exception {
        long[] k = zweiKonten();
        Line ab = Line.of(k[0], -100);
        Line an = Line.of(k[1], 100);

        erwarteFehler(HttpStatus.BAD_REQUEST, () -> bookingService.book(null, "Test", key(), null, ab, an));
        erwarteFehler(HttpStatus.BAD_REQUEST, () -> bookingService.book(BookingType.INTERNAL, " ", key(), null, ab, an));
        erwarteFehler(HttpStatus.BAD_REQUEST, () -> bookingService.book(BookingType.INTERNAL, "x".repeat(141), key(),
                null, ab, an));
        erwarteFehler(HttpStatus.BAD_REQUEST, () -> bookingService.book(BookingType.INTERNAL, "Test", "", null, ab, an));
        erwarteFehler(HttpStatus.BAD_REQUEST, () -> bookingService.book(BookingType.INTERNAL, "Test", "k".repeat(101),
                null, ab, an));
        erwarteFehler(HttpStatus.BAD_REQUEST, () -> bookingService.book(BookingType.INTERNAL, "Test", key(), null,
                Line.of(k[0], Long.MAX_VALUE), Line.of(k[1], 1)));
    }

    @Test
    void gleicherKeyGleichzeitigGibt409() throws Exception {
        long[] k = zweiKonten();
        String key = key();
        TransactionTemplate tx = new TransactionTemplate(transactionManager);
        CountDownLatch gebucht = new CountDownLatch(1);
        CountDownLatch weiter = new CountDownLatch(1);
        ExecutorService pool = Executors.newFixedThreadPool(2);
        try {
            // 1. Anfrage bucht, committet aber erst, wenn der Test es erlaubt
            Future<Long> erste = pool.submit(() -> tx.execute(s -> {
                Booking b = bookingService.book(BookingType.INTERNAL, "Erste", key, null,
                        Line.of(k[0], -100), Line.of(k[1], 100));
                gebucht.countDown();
                warte(weiter);
                return b.getId();
            }));
            assertTrue(gebucht.await(10, TimeUnit.SECONDS));

            // 2. Anfrage mit demselben Key: findet noch nichts und wartet auf die Kontosperre der ersten
            Future<Booking> zweite = pool.submit(() -> bookingService.book(BookingType.INTERNAL, "Zweite", key, null,
                    Line.of(k[0], -100), Line.of(k[1], 100)));
            Thread.sleep(500);
            assertFalse(zweite.isDone());

            weiter.countDown();
            Long id = erste.get(10, TimeUnit.SECONDS);
            ExecutionException e = assertThrows(ExecutionException.class, () -> zweite.get(10, TimeUnit.SECONDS));
            ApiException api = assertInstanceOf(ApiException.class, e.getCause());
            assertEquals(HttpStatus.CONFLICT, api.getStatus());

            assertEquals(2, lineRepository.findByBookingId(id).size());
            assertEquals(100, accountRepository.balanceOf(k[1]));
        } finally {
            weiter.countDown();
            pool.shutdownNow();
        }
    }

    @Test
    void kontenSperrenNurInnerhalbEinerTransaktion() {
        assertThrows(IllegalTransactionStateException.class,
                () -> bookingService.lockAccounts(List.of(systemKonto())));
    }

    // Doppelte Buchführung: über alle Konten zusammen ist die Summe immer 0
    @AfterAll
    void summeAllerBuchungszeilenIstNull() {
        Long sum = jdbc.queryForObject("SELECT COALESCE(SUM(amount_cents), 0) FROM booking_line", Long.class);
        assertEquals(0L, sum);
    }

    // ---------------------------------------------------------------- Hilfsmethoden

    // Neuer Nutzer: [0] = Girokonto mit Startguthaben, [1] = leeres Tagesgeldkonto
    private long[] zweiKonten() throws Exception {
        RegisteredUser user = registerAndVerify();
        Long girokonto = mainAccountId(user.userId());
        Long tagesgeld = accountRepository.save(new Account(user.userId(), AccountType.CALL, "Tagesgeld", null)).getId();
        return new long[]{girokonto, tagesgeld};
    }

    private Long systemKonto() {
        return accountRepository.findFirstByTypeAndName(AccountType.SYSTEM, BookingService.OPENING_ACCOUNT_NAME)
                .orElseThrow()
                .getId();
    }

    private static String key() {
        return "test-" + UUID.randomUUID();
    }

    private static void erwarteFehler(HttpStatus expected, Executable call) {
        ApiException e = assertThrows(ApiException.class, call);
        assertEquals(expected, e.getStatus(), e.getMessage());
    }

    private static void warte(CountDownLatch latch) {
        try {
            latch.await(10, TimeUnit.SECONDS);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException(e);
        }
    }
}
