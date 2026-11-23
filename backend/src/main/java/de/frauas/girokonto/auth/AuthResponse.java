package de.frauas.girokonto.auth;

import de.frauas.girokonto.user.UserDto;

// Antwort nach erfolgreicher Anmeldung, Bestätigung der E-Mail oder Refresh
public record AuthResponse(String accessToken, String refreshToken, UserDto user) {
}
