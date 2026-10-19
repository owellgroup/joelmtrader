package com.wayaspot.forexbot.entity;

import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.time.Instant;

@Entity
@Table(name = "account_snapshots")
@Getter
@Setter
public class AccountSnapshot {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @JsonProperty("time")
    private Instant capturedAt = Instant.now();
    private Double balance;
    private Double equity;
    private Double margin;
    private Double freeMargin;
    private Integer openPositions;
    private Long sessionId;
}
