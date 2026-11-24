package de.frauas.girokonto.config;

import com.fasterxml.jackson.databind.ObjectMapper;
import de.frauas.girokonto.auth.AuthFilter;
import de.frauas.girokonto.auth.TokenService;
import de.frauas.girokonto.common.ApiError;
import de.frauas.girokonto.user.AppUserRepository;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;

import java.io.IOException;
import java.time.Instant;

import static org.springframework.security.config.Customizer.withDefaults;

// Frei: Registrierung, Anmeldung, Codes, Status. Alles andere unter /api/** nur mit gültigem Access-Token.
@Configuration
public class SecurityConfig {

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http, TokenService tokens, AppUserRepository users,
                                                   ObjectMapper json) throws Exception {
        return http
                .cors(withDefaults())                       // nutzt die Regeln aus CorsConfig (Browser-App)
                .csrf(AbstractHttpConfigurer::disable)      // keine Cookies, Token kommt im Header
                .httpBasic(AbstractHttpConfigurer::disable)
                .formLogin(AbstractHttpConfigurer::disable)
                .logout(AbstractHttpConfigurer::disable)
                .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .authorizeHttpRequests(auth -> auth
                        .requestMatchers("/api/auth/**", "/api/status", "/error").permitAll()
                        .requestMatchers("/api/**").authenticated()
                        .anyRequest().permitAll())
                .exceptionHandling(e -> e
                        .authenticationEntryPoint((req, res, ex) ->
                                writeError(json, req, res, HttpStatus.UNAUTHORIZED, "Bitte anmelden."))
                        .accessDeniedHandler((req, res, ex) ->
                                writeError(json, req, res, HttpStatus.FORBIDDEN, "Keine Berechtigung.")))
                .addFilterBefore(new AuthFilter(tokens, users), UsernamePasswordAuthenticationFilter.class)
                .build();
    }

    // Gleiches JSON wie bei allen anderen Fehlern (GlobalExceptionHandler)
    private static void writeError(ObjectMapper json, HttpServletRequest req, HttpServletResponse res,
                                   HttpStatus status, String message) throws IOException {
        res.setStatus(status.value());
        res.setContentType(MediaType.APPLICATION_JSON_VALUE);
        res.setCharacterEncoding("UTF-8");
        json.writeValue(res.getOutputStream(), new ApiError(Instant.now(), status.value(),
                status.getReasonPhrase(), message, req.getRequestURI(), null));
    }
}
