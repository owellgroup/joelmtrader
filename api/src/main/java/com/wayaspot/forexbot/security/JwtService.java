package com.wayaspot.forexbot.security;

import com.wayaspot.forexbot.config.AppProps;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.springframework.stereotype.Service;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Duration;
import java.time.Instant;
import java.util.Date;

@Service
public class JwtService {
    private final SecretKey key;
    private final AppProps props;

    public JwtService(AppProps props) {
        this.props = props;
        byte[] raw = props.getJwtSecret().getBytes(StandardCharsets.UTF_8);
        try {
            raw = MessageDigest.getInstance("SHA-256").digest(raw);   // always >= 256 bits
        } catch (Exception ignored) { }
        this.key = Keys.hmacShaKeyFor(raw);
    }

    public String generate(String username, String role) {
        Instant now = Instant.now();
        return Jwts.builder()
                .subject(username)
                .claim("role", role)
                .issuedAt(Date.from(now))
                .expiration(Date.from(now.plus(Duration.ofDays(props.getJwtExpiryDays()))))
                .signWith(key)
                .compact();
    }

    public Claims parse(String token) {
        return Jwts.parser().verifyWith(key).build().parseSignedClaims(token).getPayload();
    }
}
