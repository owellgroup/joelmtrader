package com.wayaspot.forexbot.repo;

import com.wayaspot.forexbot.entity.BotSession;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface BotSessionRepository extends JpaRepository<BotSession, Long> {
    Optional<BotSession> findFirstByStatusOrderByIdDesc(String status);
    Page<BotSession> findAllByOrderByIdDesc(Pageable pageable);
}
