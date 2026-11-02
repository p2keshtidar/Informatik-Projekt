package de.frauas.girokonto.auth;

import de.frauas.girokonto.account.AccountService;
import de.frauas.girokonto.common.ApiException;
import de.frauas.girokonto.config.SecurityProperties;
import de.frauas.girokonto.mail.MailCodeService;
import de.frauas.girokonto.mail.MailPurpose;
import de.frauas.girokonto.user.AppUser;
import de.frauas.girokonto.user.AppUserRepository;
import de.frauas.girokonto.user.UserDto;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.Period;
import java.util.Locale;

@Service
public class AuthService {

    private static final int MIN_AGE = 18;

    private final AppUserRepository users;
    private final AccountService accountService;
    private final MailCodeService mailCodes;
    private final PasswordEncoder passwordEncoder;
    private final SecurityProperties.Login loginProps;
    private final Clock clock;

    public AuthService(AppUserRepository users, AccountService accountService, MailCodeService mailCodes,
                       PasswordEncoder passwordEncoder, SecurityProperties.Login loginProps, Clock clock) {
        this.users = users;
        this.accountService = accountService;
        this.mailCodes = mailCodes;
        this.passwordEncoder = passwordEncoder;
        this.loginProps = loginProps;
        this.clock = clock;
    }

    // Schritt 1: Nutzer anlegen (noch nicht bestätigt) und Code per Mail schicken
    @Transactional
    public CodeRequests.CodeSent register(RegisterRequest req) {
        String email = normalizeEmail(req.email());
        String phone = req.phone().replaceAll("[\\s/-]", "");

        if (Period.between(req.birthDate(), LocalDate.now(clock)).getYears() < MIN_AGE) {
            throw ApiException.badRequest("Ein Konto gibt es erst ab 18 Jahren");
        }
        PasswordPolicy.check(req.password(), email, req.firstName(), req.lastName());

        AppUser user = users.findByEmailIgnoreCase(email).orElse(null);
        if (user != null && user.isEmailVerified()) {
            throw ApiException.conflict("Diese E-Mail ist schon registriert");
        }
        boolean phoneTaken = users.findByPhone(phone)
                .filter(other -> user == null || !other.getId().equals(user.getId()))
                .isPresent();
        if (phoneTaken) {
            throw ApiException.conflict("Diese Telefonnummer wird schon verwendet");
        }

        String hash = passwordEncoder.encode(req.password());
        AppUser saved;
        if (user == null) {
            saved = users.save(new AppUser(email, hash, req.firstName().trim(), req.lastName().trim(),
                    phone, req.birthDate()));
        } else {
            // noch nicht bestätigt: Angaben überschreiben, z. B. nach Tippfehler im Namen
            user.setFirstName(req.firstName().trim());
            user.setLastName(req.lastName().trim());
            user.setPhone(phone);
            user.setPasswordHash(hash);
            saved = user;
        }
        mailCodes.send(saved, MailPurpose.VERIFY_EMAIL);
        return new CodeRequests.CodeSent("VERIFICATION_REQUIRED", email);
    }

    // Schritt 2: Code aus der Mail → E-Mail bestätigt, erst jetzt wird das Girokonto eröffnet (falls noch keins da)
    @Transactional
    public UserDto verifyEmail(String email, String code) {
        AppUser user = users.findByEmailIgnoreCase(normalizeEmail(email)).orElseThrow(AuthService::codeInvalid);
        if (user.isEmailVerified()) {
            throw ApiException.conflict("Diese E-Mail ist schon bestätigt. Bitte anmelden.");
        }
        if (!mailCodes.verify(user, MailPurpose.VERIFY_EMAIL, code)) {
            throw codeInvalid();
        }
        user.setEmailVerifiedAt(Instant.now(clock));
        // Nutzer aus der Zeit vor der E-Mail-Bestätigung haben schon ein Girokonto
        if (!accountService.hasMainAccount(user.getId())) {
            accountService.openMainAccount(user);
        }
        return UserDto.from(user);
    }

    // Antwortet immer gleich, damit niemand herausfinden kann, welche E-Mails registriert sind
    @Transactional
    public void resendVerification(String email) {
        users.findByEmailIgnoreCase(normalizeEmail(email))
                .filter(u -> !u.isEmailVerified())
                .ifPresent(u -> mailCodes.send(u, MailPurpose.VERIFY_EMAIL));
    }

    // Anmeldung in zwei Schritten: 1. E-Mail + Passwort → Code per Mail (428), 2. mit Code → angemeldet.
    // noRollbackFor: der Fehlversuch-Zähler soll auch bei einer Fehlerantwort gespeichert werden.
    @Transactional(noRollbackFor = ApiException.class)
    public UserDto login(LoginRequest req) {
        AppUser user = users.findByEmailIgnoreCase(normalizeEmail(req.email())).orElseThrow(AuthService::wrongLogin);
        Instant now = Instant.now(clock);

        if (user.isLocked(now)) {
            long minutes = Duration.between(now, user.getLockedUntil()).toMinutes() + 1;
            throw new ApiException(HttpStatus.LOCKED,
                    "Zu viele Fehlversuche. Bitte in " + minutes + " Minute(n) erneut versuchen.");
        }
        if (!passwordEncoder.matches(req.password(), user.getPasswordHash())) {
            throw failedAttempt(user, now, wrongLogin());
        }
        if (!user.isEmailVerified()) {
            mailCodes.send(user, MailPurpose.VERIFY_EMAIL);
            throw new ApiException(HttpStatus.FORBIDDEN, "Bitte zuerst die E-Mail-Adresse mit dem Code bestätigen.");
        }
        if (req.code() == null || req.code().isBlank()) {
            mailCodes.send(user, MailPurpose.LOGIN);
            throw new ApiException(HttpStatus.PRECONDITION_REQUIRED, "Wir haben dir einen Code per E-Mail geschickt.");
        }
        if (!mailCodes.verify(user, MailPurpose.LOGIN, req.code())) {
            throw failedAttempt(user, now, codeInvalid());
        }
        user.setFailedLogins(0);
        user.setLockedUntil(null);
        return UserDto.from(user);
    }

    @Transactional
    public void forgotPassword(String email) {
        users.findByEmailIgnoreCase(normalizeEmail(email))
                .filter(AppUser::isEmailVerified)
                .ifPresent(u -> mailCodes.send(u, MailPurpose.PASSWORD_RESET));
    }

    @Transactional
    public void resetPassword(CodeRequests.ResetPassword req) {
        AppUser user = users.findByEmailIgnoreCase(normalizeEmail(req.email())).orElseThrow(AuthService::codeInvalid);
        if (!mailCodes.verify(user, MailPurpose.PASSWORD_RESET, req.code())) {
            throw codeInvalid();
        }
        PasswordPolicy.check(req.newPassword(), user.getEmail(), user.getFirstName(), user.getLastName());
        user.setPasswordHash(passwordEncoder.encode(req.newPassword()));
        user.setFailedLogins(0);
        user.setLockedUntil(null);
        user.setTokenVersion(user.getTokenVersion() + 1);   // später: alte Tokens werden ungültig
        mailCodes.notice(user, "PHD Kontor: Passwort geändert",
                "dein Passwort wurde gerade geändert. Warst du das nicht, melde dich bitte sofort bei uns.");
    }

    // Nach maxFailedAttempts Fehlversuchen wird die Anmeldung für lockMinutes gesperrt
    private ApiException failedAttempt(AppUser user, Instant now, ApiException error) {
        int failed = user.getFailedLogins() + 1;
        user.setFailedLogins(failed);
        if (failed >= loginProps.maxFailedAttempts()) {
            user.setFailedLogins(0);
            user.setLockedUntil(now.plus(Duration.ofMinutes(loginProps.lockMinutes())));
            return new ApiException(HttpStatus.LOCKED, "Zu viele Fehlversuche. Die Anmeldung ist für "
                    + loginProps.lockMinutes() + " Minuten gesperrt.");
        }
        return error;
    }

    private static String normalizeEmail(String email) {
        return email.trim().toLowerCase(Locale.ROOT);
    }

    // gleiche Meldung für unbekannte E-Mail und falsches Passwort
    private static ApiException wrongLogin() {
        return new ApiException(HttpStatus.UNAUTHORIZED, "E-Mail oder Passwort falsch");
    }

    private static ApiException codeInvalid() {
        return new ApiException(HttpStatus.UNAUTHORIZED, "Der Code ist falsch oder abgelaufen.");
    }
}
