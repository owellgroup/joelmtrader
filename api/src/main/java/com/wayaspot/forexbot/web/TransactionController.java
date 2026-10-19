package com.wayaspot.forexbot.web;

import com.wayaspot.forexbot.entity.TransactionRecord;
import com.wayaspot.forexbot.repo.TransactionRepository;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.web.bind.annotation.*;

import java.util.LinkedHashMap;
import java.util.Map;

@RestController
@RequestMapping("/api/transactions")
public class TransactionController {
    private final TransactionRepository txs;

    public TransactionController(TransactionRepository txs) {
        this.txs = txs;
    }

    @GetMapping
    public Map<String, Object> list(@RequestParam(defaultValue = "0") int page, @RequestParam(defaultValue = "40") int size,
                                    @RequestParam(required = false) String type) {
        PageRequest pr = PageRequest.of(Math.max(page, 0), Math.min(Math.max(size, 1), 100));
        Page<TransactionRecord> p = (type == null || type.isBlank()) ? txs.findAllByOrderByEventTimeDesc(pr)
                : txs.findByTypeOrderByEventTimeDesc(type.toUpperCase(), pr);
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("items", p.getContent());
        out.put("page", p.getNumber());
        out.put("totalPages", p.getTotalPages());
        out.put("total", p.getTotalElements());
        return out;
    }
}
