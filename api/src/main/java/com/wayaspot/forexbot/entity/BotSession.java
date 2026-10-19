package com.wayaspot.forexbot.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.time.Instant;

@Entity
@Table(name = "bot_sessions")
@Getter
@Setter
public class BotSession {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    private Instant startedAt = Instant.now();
    private Instant stoppedAt;
    private Double openingBalance;
    private Double closingBalance;
    private String status = "RUNNING";       // RUNNING | STOPPED | FAILED
    private boolean emailSent;
    @Column(length = 600)
    private String note;
}
