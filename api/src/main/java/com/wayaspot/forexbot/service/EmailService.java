package com.wayaspot.forexbot.service;

import com.wayaspot.forexbot.config.AppProps;
import jakarta.mail.internet.MimeMessage;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.MimeMessageHelper;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;

import java.util.Arrays;
import java.util.List;
import java.util.Map;

@Service
public class EmailService {
    private static final Logger log = LoggerFactory.getLogger(EmailService.class);
    private final JavaMailSender mailSender;
    private final AppProps props;

    public EmailService(JavaMailSender mailSender, AppProps props) {
        this.mailSender = mailSender;
        this.props = props;
    }

    public List<String> recipients() {
        return Arrays.stream(props.getReportTo().split("[,;]")).map(String::trim).filter(s -> !s.isEmpty()).toList();
    }

    /** Synchronous send; returns true when the SMTP server accepted the message. */
    public boolean sendNow(String subject, String html) {
        try {
            MimeMessage msg = mailSender.createMimeMessage();
            MimeMessageHelper h = new MimeMessageHelper(msg, "UTF-8");
            h.setFrom(props.getMailFrom(), props.getBrandName());
            h.setTo(recipients().toArray(new String[0]));
            h.setSubject(subject);
            h.setText(html, true);
            mailSender.send(msg);
            return true;
        } catch (Exception e) {
            log.error("E-mail '{}' failed: {}", subject, e.getMessage());
            return false;
        }
    }

    @Async
    public void sendAsync(String subject, String html) {
        sendNow(subject, html);
    }

    @Async
    public void sendAlert(String subject, String message, String severity) {
        String color = "CRITICAL".equalsIgnoreCase(severity) ? "#dc2626" : "#d97706";
        String body = "<div style=\"border-left:4px solid " + color + ";background:#f8fafc;padding:14px 16px;border-radius:8px;font-size:14px;line-height:1.5\">"
                + EmailTemplates.esc(message) + "</div>"
                + "<p style=\"font-size:12px;color:#64748b;margin-top:16px\">Open the app to review the bot status.</p>";
        sendNow("[" + severity + "] " + subject,
                EmailTemplates.wrap(props.getBrandName(), props.getLogoUrl(), subject, severity + " alert", body));
    }
}
