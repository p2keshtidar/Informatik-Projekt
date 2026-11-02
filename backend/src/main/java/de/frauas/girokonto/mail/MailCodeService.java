package de.frauas.girokonto.mail;

import de.frauas.girokonto.config.SecurityProperties;
import de.frauas.girokonto.user.AppUser;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.Clock;
import java.time.Instant;
import java.util.HexFormat;
import java.util.Optional;

// 6-stellige Codes per Mail: Registrierung bestätigen, Anmeldung (2. Faktor), Passwort vergessen
@Service
public class MailCodeService {

    private static final SecureRandom RANDOM = new SecureRandom();

    private final MailCodeRepository codes;
    private final MailService mail;
    private final SecurityProperties.Mail props;
    private final Clock clock;

    public MailCodeService(MailCodeRepository codes, MailService mail, SecurityProperties.Mail props, Clock clock) {
        this.codes = codes;
        this.mail = mail;
        this.props = props;
        this.clock = clock;
    }

    // false, wenn vor weniger als resendSeconds schon ein Code verschickt wurde
    @Transactional
    public boolean send(AppUser user, MailPurpose purpose) {
        Instant now = Instant.now(clock);
        if (codes.existsByUserIdAndPurposeAndUsedAtIsNullAndCreatedAtAfter(
                user.getId(), purpose, now.minusSeconds(props.resendSeconds()))) {
            return false;
        }
        codes.invalidateOpen(user.getId(), purpose, now);   // ältere Codes gelten nicht mehr

        String code = String.format("%06d", RANDOM.nextInt(1_000_000));
        codes.save(new MailCode(user.getId(), purpose, hash(user.getId(), purpose, code),
                now.plusSeconds(props.codeMinutes() * 60L), now));
        mail.send(user.getEmail(), subject(purpose), text(purpose, user.getFirstName(), code));
        return true;
    }

    // Eigene Transaktion: der Versuchszähler bleibt gespeichert, auch wenn der Aufrufer danach einen Fehler wirft
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public boolean verify(AppUser user, MailPurpose purpose, String code) {
        if (code == null || !code.trim().matches("\\d{6}")) {
            return false;
        }
        Instant now = Instant.now(clock);
        Optional<MailCode> open = codes
                .findFirstByUserIdAndPurposeAndUsedAtIsNullAndExpiresAtAfterOrderByCreatedAtDesc(user.getId(), purpose, now);
        if (open.isEmpty()) {
            return false;
        }
        MailCode c = open.get();
        c.setAttempts(c.getAttempts() + 1);
        // Vergleich in konstanter Zeit
        boolean ok = MessageDigest.isEqual(
                hash(user.getId(), purpose, code.trim()).getBytes(StandardCharsets.US_ASCII),
                c.getCodeHash().getBytes(StandardCharsets.US_ASCII));
        if (ok || c.getAttempts() >= props.maxAttempts()) {
            c.setUsedAt(now);
        }
        return ok;
    }

    public void notice(AppUser user, String subject, String text) {
        mail.send(user.getEmail(), subject, "Hallo " + user.getFirstName() + ",\n\n" + text + "\n\nDein PHD Kontor");
    }

    private String hash(Long userId, MailPurpose purpose, String code) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(props.codeSecret().getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
            byte[] out = mac.doFinal((userId + ":" + purpose + ":" + code).getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(out);
        } catch (GeneralSecurityException e) {
            throw new IllegalStateException(e);
        }
    }

    private static String subject(MailPurpose purpose) {
        return switch (purpose) {
            case VERIFY_EMAIL -> "PHD Kontor: E-Mail bestätigen";
            case LOGIN -> "PHD Kontor: Dein Anmeldecode";
            case PASSWORD_RESET -> "PHD Kontor: Passwort zurücksetzen";
        };
    }

    private String text(MailPurpose purpose, String firstName, String code) {
        String what = switch (purpose) {
            case VERIFY_EMAIL -> "mit diesem Code bestätigst du deine E-Mail-Adresse";
            case LOGIN -> "mit diesem Code meldest du dich an";
            case PASSWORD_RESET -> "mit diesem Code setzt du dein Passwort zurück";
        };
        return "Hallo " + firstName + ",\n\n" + what + ":\n\n    " + code + "\n\n"
                + "Der Code gilt " + props.codeMinutes() + " Minuten. Gib ihn niemandem weiter.\n"
                + "Warst du das nicht? Dann ignoriere diese Mail.\n\nDein PHD Kontor";
    }
}
