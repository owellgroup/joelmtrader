package com.wayaspot.forexbot.entity;

import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.time.Instant;

@Entity
@Table(name = "transactions")
@Getter
@Setter
public class TransactionRecord {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @JsonProperty("time")
    private Instant eventTime = Instant.now();
    private String type;                     // BOT_START | BOT_STOP | TRADE_OPEN | TRADE_CLOSE | HALT
    private Long ticket;
    private String symbol;
    private Double amount;                   // realised P/L for TRADE_CLOSE
    private Double balanceBefore;
    private Double balanceAfter;
    @Column(length = 600)
    private String remark;
    private Long sessionId;
}
