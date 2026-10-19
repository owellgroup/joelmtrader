package com.wayaspot.forexbot.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.time.Instant;

@Entity
@Table(name = "trades")
@Getter
@Setter
public class Trade {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @Column(unique = true)
    private Long ticket;
    private Long sessionId;
    private String symbol;
    private String side;
    private Double lots;
    private Double openPrice;
    private Double closePrice;
    private Double stopLoss;
    private Double takeProfit;
    private Instant openTime;
    private Instant closeTime;
    private Double profit;
    private Double commission;
    private Double swap;
    private Double netProfit;
    private String status = "OPEN";          // OPEN | CLOSED
    private String result;                   // WIN | LOSS | BREAKEVEN
    private String closeReason;
    @Column(length = 600)
    private String remark;
    private Double score;
    private String setup;
    @Column(columnDefinition = "text")
    private String reasons;
    private Double balanceBefore;
    private Double balanceAfter;
    private Double riskAmount;
    private Double rr;
}
