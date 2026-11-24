package de.frauas.girokonto.auth;

import com.jayway.jsonpath.JsonPath;
import de.frauas.girokonto.mail.MailService;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;

import java.util.UUID;
import java.util.concurrent.ThreadLocalRandom;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.atLeastOnce;
import static org.mockito.Mockito.verify;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

// Braucht die Datenbank aus docker-compose (Port 5438). Mails werden nicht verschickt,
// der Test liest die Codes direkt aus dem Aufruf von MailService.
@SpringBootTest
@AutoConfigureMockMvc
class TokenLoginTest {

    private static final String PASSWORD = "Kontor!Blau7Wald";
    private static final Pattern CODE = Pattern.compile("\\b(\\d{6})\\b");

    @Autowired
    private MockMvc mvc;

    @MockitoBean
    private MailService mailService;

    // Antwort der letzten Bestätigung (accessToken, refreshToken, user)
    private String lastResponse;

    @Test
    void ohneTokenGibt401() throws Exception {
        mvc.perform(get("/api/accounts"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.status").value(401));
    }

    @Test
    void kaputterTokenGibt401() throws Exception {
        mvc.perform(get("/api/accounts").header("Authorization", "Bearer kein.echter.token"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void statusUndAnmeldungSindOhneTokenErreichbar() throws Exception {
        mvc.perform(get("/api/status")).andExpect(status().isOk());
        mvc.perform(post("/api/auth/login").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"niemand@test.de\",\"password\":\"falsch\"}"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.message").value("E-Mail oder Passwort falsch"));
    }

    @Test
    void nachBestaetigungAngemeldetUndMitTokenGibt200() throws Exception {
        String email = registerAndVerify();
        String body = lastResponse;

        mvc.perform(get("/api/accounts").header("Authorization", bearer(JsonPath.read(body, "$.accessToken"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].type").value("MAIN"));
        assertEquals(email, JsonPath.read(body, "$.user.email"));
    }

    @Test
    void loginInZweiSchrittenLiefertTokens() throws Exception {
        String email = registerAndVerify();

        mvc.perform(post("/api/auth/login").contentType(MediaType.APPLICATION_JSON)
                        .content(json("email", email, "password", PASSWORD)))
                .andExpect(status().isPreconditionRequired());

        String code = lastCode(email);
        String body = mvc.perform(post("/api/auth/login").contentType(MediaType.APPLICATION_JSON)
                        .content(json("email", email, "password", PASSWORD, "code", code)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accessToken").isNotEmpty())
                .andExpect(jsonPath("$.refreshToken").isNotEmpty())
                .andExpect(jsonPath("$.user.email").value(email))
                .andReturn().getResponse().getContentAsString();

        mvc.perform(get("/api/accounts").header("Authorization", bearer(JsonPath.read(body, "$.accessToken"))))
                .andExpect(status().isOk());
    }

    @Test
    void refreshLiefertNeuenAccessTokenUndAlterRefreshGiltNichtMehr() throws Exception {
        registerAndVerify();
        String oldRefresh = JsonPath.read(lastResponse, "$.refreshToken");

        String body = refresh(oldRefresh)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accessToken").isNotEmpty())
                .andReturn().getResponse().getContentAsString();

        mvc.perform(get("/api/accounts").header("Authorization", bearer(JsonPath.read(body, "$.accessToken"))))
                .andExpect(status().isOk());
        refresh(oldRefresh).andExpect(status().isUnauthorized());
        refresh("gibt-es-nicht").andExpect(status().isUnauthorized());
    }

    @Test
    void nachPasswortResetSindAlteTokensUngueltig() throws Exception {
        String email = registerAndVerify();
        String access = JsonPath.read(lastResponse, "$.accessToken");
        String refreshToken = JsonPath.read(lastResponse, "$.refreshToken");

        mvc.perform(get("/api/accounts").header("Authorization", bearer(access))).andExpect(status().isOk());

        mvc.perform(post("/api/auth/password/forgot").contentType(MediaType.APPLICATION_JSON)
                        .content(json("email", email)))
                .andExpect(status().isAccepted());
        mvc.perform(post("/api/auth/password/reset").contentType(MediaType.APPLICATION_JSON)
                        .content(json("email", email, "code", lastCode(email), "newPassword", "Neues!Gruen8Feld")))
                .andExpect(status().isNoContent());

        mvc.perform(get("/api/accounts").header("Authorization", bearer(access)))
                .andExpect(status().isUnauthorized());
        refresh(refreshToken).andExpect(status().isUnauthorized());
    }

    // ---------------------------------------------------------------- Hilfsmethoden

    // Registriert einen neuen Nutzer und bestätigt die E-Mail. Antwort steht danach in lastResponse.
    private String registerAndVerify() throws Exception {
        String email = "t" + UUID.randomUUID().toString().substring(0, 12) + "@test.de";
        String phone = "0170" + ThreadLocalRandom.current().nextLong(10_000_000L, 99_999_999L);
        mvc.perform(post("/api/auth/register").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"" + email + "\",\"password\":\"" + PASSWORD + "\","
                                + "\"firstName\":\"Test\",\"lastName\":\"Nutzer\",\"phone\":\"" + phone + "\","
                                + "\"birthDate\":\"2000-01-01\"}"))
                .andExpect(status().isAccepted());

        lastResponse = mvc.perform(post("/api/auth/verify-email").contentType(MediaType.APPLICATION_JSON)
                        .content(json("email", email, "code", lastCode(email))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accessToken").isNotEmpty())
                .andExpect(jsonPath("$.refreshToken").isNotEmpty())
                .andReturn().getResponse().getContentAsString();
        return email;
    }

    private ResultActions refresh(String refreshToken) throws Exception {
        return mvc.perform(post("/api/auth/refresh").contentType(MediaType.APPLICATION_JSON)
                .content(json("refreshToken", refreshToken)));
    }

    // Code aus der zuletzt an diese Adresse "geschickten" Mail
    private String lastCode(String email) {
        ArgumentCaptor<String> text = ArgumentCaptor.forClass(String.class);
        verify(mailService, atLeastOnce()).send(eq(email), anyString(), text.capture());
        Matcher m = CODE.matcher(text.getValue());
        if (!m.find()) {
            throw new AssertionError("Kein Code in der Mail gefunden");
        }
        return m.group(1);
    }

    private static String bearer(String token) {
        return "Bearer " + token;
    }

    private static String json(String... keyValues) {
        StringBuilder sb = new StringBuilder("{");
        for (int i = 0; i < keyValues.length; i += 2) {
            if (i > 0) {
                sb.append(',');
            }
            sb.append('"').append(keyValues[i]).append("\":\"").append(keyValues[i + 1]).append('"');
        }
        return sb.append('}').toString();
    }
}
