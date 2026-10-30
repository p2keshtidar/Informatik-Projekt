package de.frauas.girokonto.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.time.Clock;

@Configuration
public class ClockConfig {

    // Eine zentrale Uhr, damit man die Zeit in Tests festlegen kann
    @Bean
    public Clock clock() {
        return Clock.systemUTC();
    }
}
