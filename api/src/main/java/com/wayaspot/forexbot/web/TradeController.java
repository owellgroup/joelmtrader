package com.wayaspot.forexbot.web;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.wayaspot.forexbot.entity.Trade;
import com.wayaspot.forexbot.repo.TradeRepository;
import com.wayaspot.forexbot.service.EngineClient;
import com.wayaspot.forexbot.service.EngineException;
import com.wayaspot.forexbot.service.TradeStats;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.web.bind.annotation.*;

import java.util.*;

@RestController
@RequestMapping("/api/trades")
public class TradeController {
    private final TradeRepository trades;
    private final EngineClient engine;
    private final ObjectMapper mapper;

    public TradeController(TradeRepository trades, EngineClient engine, ObjectMapper mapper) {
        this.trades = trades;
        this.engine = engine;
        this.mapper = mapper;
    }

    Map<String, Object> view(Trade t) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", t.getId());
        m.put("ticket", t.getTicket());
        m.put("symbol", t.getSymbol());
        m.put("side", t.getSide());
        m.put("lots", t.getLots());
        m.put("openPrice", t.getOpenPrice());
        m.put("closePrice", t.getClosePrice());
        m.put("stopLoss", t.getStopLoss());
        m.put("takeProfit", t.getTakeProfit());
        m.put("openTime", t.getOpenTime());
        m.put("closeTime", t.getCloseTime());
        m.put("profit", t.getProfit());
        m.put("commission", t.getCommission());
        m.put("swap", t.getSwap());
        m.put("netProfit", t.getNetProfit());
        m.put("status", t.getStatus());
        m.put("result", t.getResult());
        m.put("closeReason", t.getCloseReason());
        m.put("remark", t.getRemark());
        m.put("score", t.getScore());
        m.put("setup", t.getSetup());
        m.put("rr", t.getRr());
        m.put("riskAmount", t.getRiskAmount());
        m.put("balanceBefore", t.getBalanceBefore());
        m.put("balanceAfter", t.getBalanceAfter());
        m.put("sessionId", t.getSessionId());
        try {
            if (t.getReasons() != null) m.put("reasons", mapper.readValue(t.getReasons(), List.class));
        } catch (Exception ignored) { }
        return m;
    }

    /** Live open positions (floating P/L from MT5) enriched with the bot's reasoning. */
    @GetMapping("/open")
    public List<Map<String, Object>> open() {
        List<Map<String, Object>> out = new ArrayList<>();
        try {
            JsonNode live = engine.get("/positions");
            for (JsonNode p : live) {
                long ticket = p.path("ticket").asLong();
                Map<String, Object> m = trades.findByTicket(ticket).map(this::view).orElseGet(LinkedHashMap::new);
                m.put("ticket", ticket);
                m.put("symbol", p.path("symbol").asText());
                m.put("side", p.path("side").asText());
                m.put("lots", p.path("volume").asDouble());
                m.put("openPrice", p.path("price_open").asDouble());
                m.put("currentPrice", p.path("price_current").asDouble());
                m.put("stopLoss", p.path("sl").asDouble());
                m.put("takeProfit", p.path("tp").asDouble());
                m.put("floatingProfit", p.path("profit").asDouble());
                m.put("status", "OPEN");
                out.add(m);
            }
        } catch (EngineException e) {
            for (Trade t : trades.findByStatus("OPEN")) out.add(view(t));
        }
        return out;
    }

    @GetMapping("/closed")
    public Map<String, Object> closed(@RequestParam(defaultValue = "0") int page, @RequestParam(defaultValue = "30") int size,
                                      @RequestParam(required = false) String symbol) {
        PageRequest pr = PageRequest.of(Math.max(page, 0), Math.min(Math.max(size, 1), 100), Sort.by(Sort.Direction.DESC, "closeTime"));
        Page<Trade> p = (symbol == null || symbol.isBlank()) ? trades.findByStatus("CLOSED", pr)
                : trades.findByStatusAndSymbol("CLOSED", symbol.toUpperCase(), pr);
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("items", p.getContent().stream().map(this::view).toList());
        out.put("page", p.getNumber());
        out.put("totalPages", p.getTotalPages());
        out.put("total", p.getTotalElements());
        return out;
    }

    @GetMapping("/stats")
    public Map<String, Object> stats() {
        return TradeStats.of(trades.findByStatus("CLOSED")).toMap();
    }
}
