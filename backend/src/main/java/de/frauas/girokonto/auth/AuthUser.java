package de.frauas.girokonto.auth;

import de.frauas.girokonto.user.Role;

// Der angemeldete Nutzer einer Anfrage. In Controllern so verwenden:
//   public ... methode(@AuthenticationPrincipal AuthUser me) { ... me.id() ... }
public record AuthUser(Long id, String email, Role role) {
}
