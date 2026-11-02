package de.frauas.girokonto.auth;

import jakarta.validation.constraints.NotBlank;

// code ist beim ersten Schritt leer, beim zweiten Schritt der Code aus der Mail
public record LoginRequest(
        @NotBlank String email,
        @NotBlank String password,
        String code
) {
}
