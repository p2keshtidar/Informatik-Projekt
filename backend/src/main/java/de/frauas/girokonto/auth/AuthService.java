package de.frauas.girokonto.auth;

import de.frauas.girokonto.account.AccountService;
import de.frauas.girokonto.common.ApiException;
import de.frauas.girokonto.user.AppUser;
import de.frauas.girokonto.user.AppUserRepository;
import de.frauas.girokonto.user.UserDto;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.LocalDate;
import java.time.Period;
import java.util.Locale;

@Service
public class AuthService {

    private static final int MIN_AGE = 18;

    private final AppUserRepository users;
    private final AccountService accountService;
    private final PasswordEncoder passwordEncoder;
    private final Clock clock;

    public AuthService(AppUserRepository users, AccountService accountService,
                       PasswordEncoder passwordEncoder, Clock clock) {
        this.users = users;
        this.accountService = accountService;
        this.passwordEncoder = passwordEncoder;
        this.clock = clock;
    }

    // Nutzer und Girokonto in einer Transaktion: geht etwas schief, wird nichts gespeichert
    @Transactional
    public UserDto register(RegisterRequest req) {
        String email = req.email().trim().toLowerCase(Locale.ROOT);
        String phone = req.phone().replaceAll("[\\s/-]", "");

        if (Period.between(req.birthDate(), LocalDate.now(clock)).getYears() < MIN_AGE) {
            throw ApiException.badRequest("Ein Konto gibt es erst ab 18 Jahren");
        }
        if (users.existsByEmailIgnoreCase(email)) {
            throw ApiException.conflict("Diese E-Mail ist schon registriert");
        }
        if (users.existsByPhone(phone)) {
            throw ApiException.conflict("Diese Telefonnummer wird schon verwendet");
        }

        AppUser user = users.save(new AppUser(email, passwordEncoder.encode(req.password()),
                req.firstName().trim(), req.lastName().trim(), phone, req.birthDate()));
        accountService.openMainAccount(user);
        return UserDto.from(user);
    }

    @Transactional(readOnly = true)
    public UserDto login(LoginRequest req) {
        AppUser user = users.findByEmailIgnoreCase(req.email().trim())
                .filter(u -> passwordEncoder.matches(req.password(), u.getPasswordHash()))
                .orElseThrow(() -> new ApiException(HttpStatus.UNAUTHORIZED, "E-Mail oder Passwort falsch"));
        return UserDto.from(user);
    }
}
