package com.wayaspot.forexbot.web;

import com.wayaspot.forexbot.entity.BotSession;
import com.wayaspot.forexbot.entity.Trade;
import com.wayaspot.forexbot.repo.BotSessionRepository;
import com.wayaspot.forexbot.repo.TradeRepository;
import com.wayaspot.forexbot.service.ReportService;
import com.wayaspot.forexbot.service.TradeStats;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.*;

@RestController
@RequestMapping("/api/reports")
public class ReportController {
    private final BotSessionRepository sessions;
    private final TradeRepository trades;
    private final ReportService reports;

    public ReportController(BotSessionRepository sessions, TradeRepository trades, ReportService reports) {
        this.sessions = sessions;
        this.trades = trades;
        this.reports = reports;
    }

    @GetMapping("/sessions")
    public List<Map<String, Object>> sessions(@RequestParam(defaultValue = "0") int page, @RequestParam(defaultValue = "30") int size) {
        List<Map<String, Object>> out = new ArrayList<>();
        for (BotSession s : sessions.findAllByOrderByIdDesc(PageRequest.of(Math.max(page, 0), Math.min(Math.max(size, 1), 100))).getContent()) {
            List<Trade> closed = trades.findBySessionIdOrderByOpenTimeAsc(s.getId()).stream()
                    .filter(t -> "CLOSED".equals(t.getStatus())).toList();
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("id", s.getId());
            m.put("startedAt", s.getStartedAt());
            m.put("stoppedAt", s.getStoppedAt());
            m.put("status", s.getStatus());
            m.put("openingBalance", s.getOpeningBalance());
            m.put("closingBalance", s.getClosingBalance());
            m.put("emailSent", s.isEmailSent());
            m.put("note", s.getNote());
            m.put("stats", TradeStats.of(closed).toMap());
            out.add(m);
        }
        return out;
    }

    @PostMapping("/sessions/{id}/resend")
    public Map<String, Object> resend(@PathVariable Long id) {
        if (!sessions.existsById(id)) throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Session not found");
        reports.sendSessionReport(id);
        return Map.of("queued", true);
    }

    @PostMapping("/daily")
    public Map<String, Object> daily() {
        return Map.of("sent", reports.sendDigest(LocalDate.now(ZoneOffset.UTC)));
    }
}
