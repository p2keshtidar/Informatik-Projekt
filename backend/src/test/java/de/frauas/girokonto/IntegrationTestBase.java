package de.frauas.girokonto;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import de.frauas.girokonto.account.Account;
import de.frauas.girokonto.account.AccountRepository;
import de.frauas.girokonto.account.AccountType;
import de.frauas.girokonto.mail.MailService;
import org.mockito.ArgumentCaptor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ThreadLocalRandom;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.atLeastOnce;
import static org.mockito.Mockito.verify;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

// Basis für alle Tests mit Datenbank. Braucht die PostgreSQL aus docker-compose (Port 5438),
// im CI dieselbe Datenbank als Service.
//
// Gemockt wird nur MailService: die echte Code-Prüfung (Hash, Versuchszähler, Ablaufzeit) bleibt aktiv,
// der Test liest den Code aus dem Mailtext.
//
// Kein @Transactional auf den Tests: MailCodeService.verify läuft in einer eigenen Transaktion
// (REQUIRES_NEW) und muss den Nutzer schon gespeichert sehen. Deshalb immer newEmail()/newPhone()
// benutzen, damit sich Tests nicht in die Quere kommen.
@SpringBootTest
@AutoConfigureMockMvc
public abstract class IntegrationTestBase {

    protected static final String PASSWORD = "Kontor!Blau7Wald";
    protected static final String BIRTH_DATE = "2000-01-01";

    private static final Pattern CODE = Pattern.compile("\\b(\\d{6})\\b");

    @Autowired
    protected MockMvc mvc;

    @Autowired
    protected ObjectMapper json;

    @Autowired
    protected AccountRepository accountRepository;

    @MockitoBean
    protected MailService mailService;

    // Ergebnis von registerAndVerify(). accessToken ist null, solange verify-email keine Tokens liefert.
    protected record RegisteredUser(String email, Long userId, String accessToken) {
    }

    // Registriert einen neuen Nutzer über die API und bestätigt die E-Mail mit dem Code aus der Mail.
    // Danach hat der Nutzer ein Girokonto mit Startguthaben.
    protected RegisteredUser registerAndVerify() throws Exception {
        String email = newEmail();
        mvc.perform(post("/api/auth/register").contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of(
                                "email", email,
                                "password", PASSWORD,
                                "firstName", "Test",
                                "lastName", "Nutzer",
                                "phone", newPhone(),
                                "birthDate", BIRTH_DATE))))
                .andExpect(status().isAccepted());

        String body = mvc.perform(post("/api/auth/verify-email").contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("email", email, "code", lastCode(email)))))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString(StandardCharsets.UTF_8);

        // Mit Token-Login: {accessToken, refreshToken, user}. Ohne: direkt der Nutzer.
        JsonNode root = json.readTree(body);
        JsonNode user = root.hasNonNull("user") ? root.get("user") : root;
        String accessToken = root.hasNonNull("accessToken") ? root.get("accessToken").asText() : null;
        return new RegisteredUser(email, user.get("id").asLong(), accessToken);
    }

    // 6-stelliger Code aus der zuletzt an diese Adresse "geschickten" Mail
    protected String lastCode(String email) {
        ArgumentCaptor<String> text = ArgumentCaptor.forClass(String.class);
        verify(mailService, atLeastOnce()).send(eq(email), anyString(), text.capture());
        Matcher m = CODE.matcher(text.getValue());
        if (!m.find()) {
            throw new AssertionError("Kein Code in der Mail an " + email + " gefunden");
        }
        return m.group(1);
    }

    protected String newEmail() {
        return "test." + UUID.randomUUID().toString().replace("-", "") + "@test.de";
    }

    protected String newPhone() {
        return "0170" + ThreadLocalRandom.current().nextLong(1_000_000_000L, 10_000_000_000L);
    }

    protected String bearer(String token) {
        return "Bearer " + token;
    }

    // ID des Girokontos (MAIN) eines Nutzers
    protected Long mainAccountId(Long userId) {
        List<Account> own = accountRepository.findByOwnerIdOrderById(userId);
        return own.stream()
                .filter(a -> a.getType() == AccountType.MAIN)
                .findFirst()
                .orElseThrow(() -> new AssertionError("Nutzer " + userId + " hat kein Girokonto"))
                .getId();
    }
}
