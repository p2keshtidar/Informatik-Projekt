package de.frauas.girokonto.auth;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public final class CodeRequests {

    private CodeRequests() {
    }

    public record Email(@NotBlank @jakarta.validation.constraints.Email String email) {
    }

    public record Verify(@NotBlank String email, @NotBlank String code) {
    }

    public record ResetPassword(@NotBlank String email, @NotBlank String code,
                                @NotBlank @Size(max = 100) String newPassword) {
    }

    // Antwort, wenn ein Code per Mail verschickt wurde
    public record CodeSent(String status, String email) {
    }
}
