package de.frauas.girokonto.user;

import java.time.LocalDate;

// Was die App über einen Nutzer sieht (ohne Passwort-Hash usw.)
public record UserDto(
        Long id,
        String email,
        String firstName,
        String lastName,
        String phone,
        LocalDate birthDate,
        Role role,
        boolean emailVerified
) {
    public static UserDto from(AppUser u) {
        return new UserDto(u.getId(), u.getEmail(), u.getFirstName(), u.getLastName(), u.getPhone(),
                u.getBirthDate(), u.getRole(), u.isEmailVerified());
    }
}
