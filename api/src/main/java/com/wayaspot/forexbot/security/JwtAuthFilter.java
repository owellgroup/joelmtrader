package com.wayaspot.forexbot.security;

import com.wayaspot.forexbot.config.AppProps;
import com.wayaspot.forexbot.repo.AdminUserRepository;
import io.jsonwebtoken.Claims;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.List;

public class JwtAuthFilter extends OncePerRequestFilter {
    private final JwtService jwt;
    private final AppProps props;
    private final AdminUserRepository users;

    public JwtAuthFilter(JwtService jwt, AppProps props, AdminUserRepository users) {
        this.jwt = jwt;
        this.props = props;
        this.users = users;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest req, HttpServletResponse res, FilterChain chain)
            throws ServletException, IOException {
        String path = req.getRequestURI();
        if (path.startsWith("/internal/")) {
            String k = req.getHeader("X-Internal-Key");
            if (k != null && MessageDigest.isEqual(k.getBytes(StandardCharsets.UTF_8),
                    props.getInternalApiKey().getBytes(StandardCharsets.UTF_8))) {
                SecurityContextHolder.getContext().setAuthentication(new UsernamePasswordAuthenticationToken(
                        "engine", null, List.of(new SimpleGrantedAuthority("ROLE_ENGINE"))));
            }
        } else {
            String h = req.getHeader("Authorization");
            if (h != null && h.startsWith("Bearer ")) {
                try {
                    Claims c = jwt.parse(h.substring(7));
                    users.findByUsername(c.getSubject()).filter(u -> u.isEnabled()).ifPresent(u ->
                            SecurityContextHolder.getContext().setAuthentication(new UsernamePasswordAuthenticationToken(
                                    u.getUsername(), null, List.of(new SimpleGrantedAuthority("ROLE_" + u.getRole())))));
                } catch (Exception ignored) {
                    // invalid / expired token -> stays unauthenticated -> 401
                }
            }
        }
        chain.doFilter(req, res);
    }
}
