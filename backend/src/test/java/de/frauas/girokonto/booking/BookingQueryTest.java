package de.frauas.girokonto.booking;

import de.frauas.girokonto.IntegrationTestBase;
import de.frauas.girokonto.booking.BookingService.Line;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

import java.sql.Timestamp;
import java.time.Instant;
import java.util.UUID;

import static org.hamcrest.Matchers.hasSize;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

// Umsätze abrufen: GET /api/accounts/{id}/bookings und GET /api/bookings/{id}
class BookingQueryTest extends IntegrationTestBase {

    @Autowired
    private BookingService bookingService;

    @Autowired
    private JdbcTemplate jdbc;

    // Anna überweist an Ben. Jeder hat 10.000 € Startguthaben.
    private RegisteredUser anna;
    private RegisteredUser ben;
    private Long annaKonto;
    private Long benKonto;

    @BeforeEach
    void zweiNutzer() throws Exception {
        anna = registerAndVerify();
        ben = registerAndVerify();
        annaKonto = mainAccountId(anna.userId());
        benKonto = mainAccountId(ben.userId());
        jdbc.update("UPDATE app_user SET first_name = 'Anna', last_name = 'Apfelbaum' WHERE id = ?", anna.userId());
        jdbc.update("UPDATE app_user SET first_name = 'Ben', last_name = 'Birnbaum' WHERE id = ?", ben.userId());
    }

    // ---------------------------------------------------------------- Pflicht-Tests

    @Test
    void startguthabenErscheintInDerListe() throws Exception {
        alsAnna(get("/api/accounts/{id}/bookings", annaKonto))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items", hasSize(1)))
                .andExpect(jsonPath("$.items[0].type").value("OPENING"))
                .andExpect(jsonPath("$.items[0].description").value("Startguthaben"))
                .andExpect(jsonPath("$.items[0].amountCents").value(1_000_000))
                .andExpect(jsonPath("$.items[0].counterpartyName").value(BookingService.OPENING_ACCOUNT_NAME))
                .andExpect(jsonPath("$.totalItems").value(1))
                .andExpect(jsonPath("$.hasMore").value(false));
    }

    @Test
    void filterZeitraum() throws Exception {
        // feste Daten, damit der Test nicht vom heutigen Tag abhängt
        jdbc.update("UPDATE booking SET booked_at = '2026-01-01T09:00:00Z' WHERE idempotency_key = ?",
                "opening-" + anna.userId());
        Long alt = ueberweise(2_500, "Miete November");
        setzeDatum(alt, "2026-11-15T10:00:00Z");
        Long neu = ueberweise(1_000, "Pizza");
        setzeDatum(neu, "2026-12-03T22:30:00Z");   // in Deutschland schon der 03.12., 23:30 Uhr

        alsAnna(get("/api/accounts/{id}/bookings", annaKonto)
                .param("from", "2026-12-01").param("to", "2026-12-03"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items", hasSize(1)))
                .andExpect(jsonPath("$.items[0].id").value(neu));

        alsAnna(get("/api/accounts/{id}/bookings", annaKonto)
                .param("from", "2026-11-01").param("to", "2026-11-30"))
                .andExpect(jsonPath("$.items", hasSize(1)))
                .andExpect(jsonPath("$.items[0].id").value(alt));

        // Startdatum nach Enddatum
        alsAnna(get("/api/accounts/{id}/bookings", annaKonto)
                .param("from", "2026-12-05").param("to", "2026-12-01"))
                .andExpect(status().isBadRequest());

        // kein gültiges Datum → 400, nicht 500
        alsAnna(get("/api/accounts/{id}/bookings", annaKonto).param("from", "gestern"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void filterBetrag() throws Exception {
        ueberweise(2_500, "Kino");          //  25,00 €
        ueberweise(30_000, "Fahrrad");      // 300,00 €

        // 10 € bis 500 €: Kino und Fahrrad, nicht das Startguthaben. Betrag ohne Vorzeichen.
        alsAnna(get("/api/accounts/{id}/bookings", annaKonto)
                .param("minCents", "1000").param("maxCents", "50000"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items", hasSize(2)))
                .andExpect(jsonPath("$.items[0].description").value("Fahrrad"))
                .andExpect(jsonPath("$.items[0].amountCents").value(-30_000))
                .andExpect(jsonPath("$.items[1].description").value("Kino"));

        alsAnna(get("/api/accounts/{id}/bookings", annaKonto).param("minCents", "50000").param("maxCents", "1000"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void filterText() throws Exception {
        ueberweise(2_500, "Miete Dezember");
        ueberweise(1_000, "Pizza");

        // Text im Verwendungszweck, Groß-/Kleinschreibung egal
        alsAnna(get("/api/accounts/{id}/bookings", annaKonto).param("q", "MIETE"))
                .andExpect(jsonPath("$.items", hasSize(1)))
                .andExpect(jsonPath("$.items[0].description").value("Miete Dezember"));

        // Text im Namen der Gegenseite
        alsAnna(get("/api/accounts/{id}/bookings", annaKonto).param("q", "birnbaum"))
                .andExpect(jsonPath("$.items", hasSize(2)))
                .andExpect(jsonPath("$.items[0].counterpartyName").value("Ben Birnbaum"));

        // % ist kein Platzhalter
        alsAnna(get("/api/accounts/{id}/bookings", annaKonto).param("q", "%"))
                .andExpect(jsonPath("$.items", hasSize(0)));
    }

    @Test
    void ausSichtDesEmpfaengersPositiv() throws Exception {
        ueberweise(4_200, "Geschenk");

        alsBen(get("/api/accounts/{id}/bookings", benKonto).param("q", "Geschenk"))
                .andExpect(jsonPath("$.items[0].amountCents").value(4_200))
                .andExpect(jsonPath("$.items[0].counterpartyName").value("Anna Apfelbaum"))
                .andExpect(jsonPath("$.items[0].category").value("SONSTIGES"));
    }

    @Test
    void seitenweiseNeuesteZuerst() throws Exception {
        ueberweise(100, "Eins");
        ueberweise(200, "Zwei");
        ueberweise(300, "Drei");   // + Startguthaben = 4 Buchungen

        alsAnna(get("/api/accounts/{id}/bookings", annaKonto).param("size", "3"))
                .andExpect(jsonPath("$.items", hasSize(3)))
                .andExpect(jsonPath("$.items[0].description").value("Drei"))
                .andExpect(jsonPath("$.totalItems").value(4))
                .andExpect(jsonPath("$.hasMore").value(true));

        alsAnna(get("/api/accounts/{id}/bookings", annaKonto).param("size", "3").param("page", "1"))
                .andExpect(jsonPath("$.items", hasSize(1)))
                .andExpect(jsonPath("$.items[0].description").value("Startguthaben"))
                .andExpect(jsonPath("$.hasMore").value(false));

        alsAnna(get("/api/accounts/{id}/bookings", annaKonto).param("size", "500"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void fremdesKontoGibt403() throws Exception {
        alsAnna(get("/api/accounts/{id}/bookings", benKonto))
                .andExpect(status().isForbidden());
    }

    @Test
    void unbekanntesKontoGibt404() throws Exception {
        alsAnna(get("/api/accounts/{id}/bookings", Long.MAX_VALUE))
                .andExpect(status().isNotFound());
    }

    @Test
    void ohneTokenGibt401() throws Exception {
        mvc.perform(get("/api/accounts/{id}/bookings", annaKonto))
                .andExpect(status().isUnauthorized());
        mvc.perform(get("/api/bookings/{id}", 1))
                .andExpect(status().isUnauthorized());
    }

    // ---------------------------------------------------------------- Detail

    @Test
    void detailMitAllenZeilen() throws Exception {
        Long id = ueberweise(1_250, "Kaffee");

        alsAnna(get("/api/bookings/{id}", id))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(id))
                .andExpect(jsonPath("$.type").value("TRANSFER"))
                .andExpect(jsonPath("$.description").value("Kaffee"))
                .andExpect(jsonPath("$.lines", hasSize(2)))
                .andExpect(jsonPath("$.lines[0].name").value("Anna Apfelbaum"))
                .andExpect(jsonPath("$.lines[0].amountCents").value(-1_250))
                .andExpect(jsonPath("$.lines[0].own").value(true))
                .andExpect(jsonPath("$.lines[1].name").value("Ben Birnbaum"))
                .andExpect(jsonPath("$.lines[1].amountCents").value(1_250))
                .andExpect(jsonPath("$.lines[1].own").value(false))
                // fremde IBAN nur maskiert
                .andExpect(jsonPath("$.lines[1].iban").value(org.hamcrest.Matchers.containsString("****")));

        // Ben darf sie auch sehen (er ist Empfänger)
        alsBen(get("/api/bookings/{id}", id)).andExpect(status().isOk());
    }

    @Test
    void detailFremderBuchungGibt403UndUnbekannteGibt404() throws Exception {
        Long id = ueberweise(500, "Nur Anna und Ben");
        RegisteredUser carla = registerAndVerify();

        mvc.perform(get("/api/bookings/{id}", id).header("Authorization", bearer(carla.accessToken())))
                .andExpect(status().isForbidden());
        alsAnna(get("/api/bookings/{id}", Long.MAX_VALUE))
                .andExpect(status().isNotFound());
    }

    // ---------------------------------------------------------------- Hilfsmethoden

    // Anna → Ben, wie später der TransferService (Kategorie SONSTIGES). Gibt die Buchungs-ID zurück.
    private Long ueberweise(long cents, String zweck) {
        return bookingService.book(BookingType.TRANSFER, zweck, "test-" + UUID.randomUUID(), anna.userId(),
                new Line(annaKonto, -cents, "SONSTIGES"),
                new Line(benKonto, cents, "SONSTIGES")).getId();
    }

    // Buchungsdatum nachträglich setzen (die App-Uhr läuft im Test in Echtzeit)
    private void setzeDatum(Long bookingId, String instant) {
        jdbc.update("UPDATE booking SET booked_at = ? WHERE id = ?", Timestamp.from(Instant.parse(instant)), bookingId);
    }

    private ResultActions alsAnna(MockHttpServletRequestBuilder request) throws Exception {
        return mvc.perform(request.header("Authorization", bearer(anna.accessToken())));
    }

    private ResultActions alsBen(MockHttpServletRequestBuilder request) throws Exception {
        return mvc.perform(request.header("Authorization", bearer(ben.accessToken())));
    }
}
