package de.frauas.girokonto.auth;

import de.frauas.girokonto.user.UserDto;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private final AuthService authService;

    public AuthController(AuthService authService) {
        this.authService = authService;
    }

    // 202 Accepted: angenommen, fertig erst nach Bestätigung mit dem Code
    @PostMapping("/register")
    @ResponseStatus(HttpStatus.ACCEPTED)
    public CodeRequests.CodeSent register(@Valid @RequestBody RegisterRequest req) {
        return authService.register(req);
    }

    @PostMapping("/verify-email")
    public UserDto verifyEmail(@Valid @RequestBody CodeRequests.Verify req) {
        return authService.verifyEmail(req.email(), req.code());
    }

    @PostMapping("/resend-code")
    @ResponseStatus(HttpStatus.ACCEPTED)
    public void resendCode(@Valid @RequestBody CodeRequests.Email req) {
        authService.resendVerification(req.email());
    }

    @PostMapping("/login")
    public UserDto login(@Valid @RequestBody LoginRequest req) {
        return authService.login(req);
    }

    @PostMapping("/password/forgot")
    @ResponseStatus(HttpStatus.ACCEPTED)
    public void forgotPassword(@Valid @RequestBody CodeRequests.Email req) {
        authService.forgotPassword(req.email());
    }

    @PostMapping("/password/reset")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void resetPassword(@Valid @RequestBody CodeRequests.ResetPassword req) {
        authService.resetPassword(req);
    }
}
