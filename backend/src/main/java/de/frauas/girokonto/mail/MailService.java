package de.frauas.girokonto.mail;

import de.frauas.girokonto.common.ApiException;
import de.frauas.girokonto.config.SecurityProperties;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.mail.MailException;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.stereotype.Service;

@Service
public class MailService {

    private static final Logger log = LoggerFactory.getLogger(MailService.class);

    private final JavaMailSender sender;
    private final SecurityProperties.Mail props;

    public MailService(JavaMailSender sender, SecurityProperties.Mail props) {
        this.sender = sender;
        this.props = props;
    }

    public void send(String to, String subject, String text) {
        SimpleMailMessage msg = new SimpleMailMessage();
        msg.setFrom(props.from());
        msg.setTo(to);
        msg.setSubject(subject);
        msg.setText(text);
        try {
            sender.send(msg);
        } catch (MailException e) {
            // Empfänger und Inhalt nicht loggen, die Mail enthält einen Code
            log.warn("Mailversand fehlgeschlagen: {}", e.getClass().getSimpleName());
            throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE,
                    "Die E-Mail konnte nicht gesendet werden. Bitte später noch einmal versuchen.");
        }
    }
}
