package de.frauas.girokonto.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

// Werte aus application.yml (app.mail.* und app.login.*)
public final class SecurityProperties {

    private SecurityProperties() {
    }

    @ConfigurationProperties(prefix = "app.mail")
    public record Mail(String from, int codeMinutes, int resendSeconds, int maxAttempts, String codeSecret) {
    }

    @ConfigurationProperties(prefix = "app.login")
    public record Login(int maxFailedAttempts, int lockMinutes) {
    }
}
