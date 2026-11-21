package de.frauas.girokonto.config;

import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Configuration;

@Configuration
@EnableConfigurationProperties({SecurityProperties.Mail.class, SecurityProperties.Login.class,
        SecurityProperties.Token.class})
public class PropertiesConfig {
}
