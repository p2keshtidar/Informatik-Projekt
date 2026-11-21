package de.frauas.girokonto.auth;

import de.frauas.girokonto.common.ApiException;
import de.frauas.girokonto.config.SecurityProperties;
import de.frauas.girokonto.user.AppUser;
import de.frauas.girokonto.user.Role;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.Date;
import java.util.HexFormat;
import java.util.Optional;

// Access-Token: kurzlebiges JWT (15 Min.), wird bei jeder Anfrage im Header mitgeschickt.
// Refresh-Token: langer Zufallswert (30 Tage), damit holt sich die App einen neuen Access-Token.
@Service
public class TokenService {

    private static final SecureRandom RANDOM = new SecureRandom();
    private static final String CLAIM_EMAIL = "email";
    private static final String CLAIM_ROLE = "role";
    private static final String CLAIM_TOKEN_VERSION = "tv";

    private final RefreshTokenRepository refreshTokens;
    private final SecurityProperties.Token props;
    private final SecretKey key;
    private final Clock clock;

    public TokenService(RefreshTokenRepository refreshTokens, SecurityProperties.Token props, Clock clock) {
        if (props.secret() == null || props.secret().length() < 32) {
            throw new IllegalStateException("app.token.secret muss mindestens 32 Zeichen lang sein");
        }
        this.refreshTokens = refreshTokens;
        this.props = props;
        this.key = Keys.hmacShaKeyFor(props.secret().getBytes(StandardCharsets.UTF_8));
        this.clock = clock;
    }

    // Inhalt eines gültigen Access-Tokens
    public record AccessClaims(Long userId, String email, Role role, int tokenVersion) {
    }

    public String createAccessToken(AppUser user) {
        Instant now = Instant.now(clock);
        return Jwts.builder()
                .subject(String.valueOf(user.getId()))
                .claim(CLAIM_EMAIL, user.getEmail())
                .claim(CLAIM_ROLE, user.getRole().name())
                .claim(CLAIM_TOKEN_VERSION, user.getTokenVersion())
                .issuedAt(Date.from(now))
                .expiration(Date.from(now.plus(Duration.ofMinutes(props.accessMinutes()))))
                .signWith(key)
                .compact();
    }

    // Leer, wenn der Token kaputt, falsch signiert oder abgelaufen ist
    public Optional<AccessClaims> parseAccessToken(String token) {
        try {
            Claims c = Jwts.parser()
                    .verifyWith(key)
                    .clock(() -> Date.from(Instant.now(clock)))
                    .build()
                    .parseSignedClaims(token)
                    .getPayload();
            return Optional.of(new AccessClaims(
                    Long.valueOf(c.getSubject()),
                    c.get(CLAIM_EMAIL, String.class),
                    Role.valueOf(c.get(CLAIM_ROLE, String.class)),
                    c.get(CLAIM_TOKEN_VERSION, Integer.class)));
        } catch (JwtException | IllegalArgumentException | NullPointerException e) {
            return Optional.empty();
        }
    }

    // Neuer Refresh-Token: der Zufallswert geht an die App, in der Datenbank steht nur sein Hash
    @Transactional
    public String createRefreshToken(AppUser user) {
        byte[] bytes = new byte[32];
        RANDOM.nextBytes(bytes);
        String token = Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
        Instant now = Instant.now(clock);
        refreshTokens.save(new RefreshToken(user.getId(), sha256(token),
                now.plus(Duration.ofDays(props.refreshDays())), now));
        return token;
    }

    // Prüft den Refresh-Token und macht ihn ungültig (jeder Refresh-Token ist nur einmal verwendbar).
    // Gibt die Nutzer-ID zurück, für die ein neues Token-Paar ausgestellt werden darf.
    @Transactional(noRollbackFor = ApiException.class)
    public Long useRefreshToken(String token) {
        RefreshToken stored = refreshTokens.findByTokenHash(sha256(token))
                .orElseThrow(TokenService::refreshInvalid);
        if (!stored.isUsable(Instant.now(clock))) {
            throw refreshInvalid();
        }
        stored.setRevoked(true);
        return stored.getUserId();
    }

    @Transactional
    public void revokeAll(Long userId) {
        refreshTokens.revokeAllOf(userId);
    }

    static String sha256(String value) {
        try {
            byte[] hash = MessageDigest.getInstance("SHA-256").digest(value.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(hash);
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }

    private static ApiException refreshInvalid() {
        return ApiException.unauthorized("Die Anmeldung ist abgelaufen. Bitte erneut anmelden.");
    }
}
