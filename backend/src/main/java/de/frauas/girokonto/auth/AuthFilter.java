package de.frauas.girokonto.auth;

import de.frauas.girokonto.user.AppUser;
import de.frauas.girokonto.user.AppUserRepository;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.http.HttpHeaders;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.List;

// Liest "Authorization: Bearer <token>" und setzt den angemeldeten Nutzer.
// Ohne oder mit ungültigem Token bleibt die Anfrage anonym; geschützte Pfade antworten dann mit 401.
public class AuthFilter extends OncePerRequestFilter {

    private static final String PREFIX = "Bearer ";

    private final TokenService tokens;
    private final AppUserRepository users;

    public AuthFilter(TokenService tokens, AppUserRepository users) {
        this.tokens = tokens;
        this.users = users;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {
        String header = request.getHeader(HttpHeaders.AUTHORIZATION);
        if (header != null && header.startsWith(PREFIX)) {
            tokens.parseAccessToken(header.substring(PREFIX.length()).trim())
                    .flatMap(claims -> users.findById(claims.userId())
                            // nach Passwortänderung ist tokenVersion höher: alte Tokens gelten nicht mehr
                            .filter(u -> u.getTokenVersion() == claims.tokenVersion())
                            .filter(AppUser::isEmailVerified))
                    .ifPresent(this::authenticate);
        }
        chain.doFilter(request, response);
    }

    private void authenticate(AppUser user) {
        AuthUser me = new AuthUser(user.getId(), user.getEmail(), user.getRole());
        var auth = new UsernamePasswordAuthenticationToken(me, null,
                List.of(new SimpleGrantedAuthority("ROLE_" + user.getRole().name())));
        SecurityContextHolder.getContext().setAuthentication(auth);
    }
}
