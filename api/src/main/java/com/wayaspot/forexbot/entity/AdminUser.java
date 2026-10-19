package com.wayaspot.forexbot.entity;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.time.Instant;

@Entity
@Table(name = "admin_users")
@Getter
@Setter
public class AdminUser {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @Column(nullable = false, unique = true)
    private String username;
    @JsonIgnore
    @Column(nullable = false)
    private String passwordHash;
    @Column(nullable = false)
    private String role = "ADMIN";          // SUPER_ADMIN | ADMIN
    private boolean enabled = true;
    private Instant createdAt = Instant.now();
    private Instant lastLoginAt;
}
