package com.wayaspot.forexbot.repo;

import com.wayaspot.forexbot.entity.Trade;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

public interface TradeRepository extends JpaRepository<Trade, Long> {
    Optional<Trade> findByTicket(Long ticket);
    Page<Trade> findByStatus(String status, Pageable pageable);
    Page<Trade> findByStatusAndSymbol(String status, String symbol, Pageable pageable);
    List<Trade> findByStatus(String status);
    List<Trade> findBySessionIdOrderByOpenTimeAsc(Long sessionId);
    List<Trade> findByStatusAndCloseTimeGreaterThanEqualOrderByCloseTimeAsc(String status, Instant from);
    List<Trade> findByStatusAndCloseTimeBetweenOrderByCloseTimeAsc(String status, Instant from, Instant to);
}
