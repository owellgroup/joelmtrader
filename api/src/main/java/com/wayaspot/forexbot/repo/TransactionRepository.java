package com.wayaspot.forexbot.repo;

import com.wayaspot.forexbot.entity.TransactionRecord;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

public interface TransactionRepository extends JpaRepository<TransactionRecord, Long> {
    Page<TransactionRecord> findAllByOrderByEventTimeDesc(Pageable pageable);
    Page<TransactionRecord> findByTypeOrderByEventTimeDesc(String type, Pageable pageable);
}
