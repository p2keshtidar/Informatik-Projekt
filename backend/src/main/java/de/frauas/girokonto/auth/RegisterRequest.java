package de.frauas.girokonto.auth;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Past;
import jakarta.validation.constraints.Size;

import java.time.LocalDate;

// Passwortregeln prüft PasswordPolicy im AuthService
public record RegisterRequest(
        @NotBlank @Email String email,
        @NotBlank @Size(max = 100) String password,
        @NotBlank @Size(max = 100) String firstName,
        @NotBlank @Size(max = 100) String lastName,
        @NotBlank @Size(max = 30) String phone,
        @NotNull @Past LocalDate birthDate
) {
}
