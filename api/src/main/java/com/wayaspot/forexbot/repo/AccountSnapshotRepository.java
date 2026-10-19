package com.wayaspot.forexbot.repo;

import com.wayaspot.forexbot.entity.AccountSnapshot;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface AccountSnapshotRepository extends JpaRepository<AccountSnapshot, Long> {
    List<AccountSnapshot> findTop300ByOrderByCapturedAtDesc();
}
