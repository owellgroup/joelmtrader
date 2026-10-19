package com.wayaspot.forexbot.web;

import com.fasterxml.jackson.databind.JsonNode;
import com.wayaspot.forexbot.service.EngineClient;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/market")
public class MarketController {
    private final EngineClient engine;

    public MarketController(EngineClient engine) {
        this.engine = engine;
    }

    @GetMapping("/quotes")
    public JsonNode quotes() {
        return engine.get("/quotes");
    }

    @GetMapping("/scan")
    public JsonNode scan() {
        return engine.get("/scan");
    }

    @PostMapping("/scan/now")
    public JsonNode scanNow() {
        return engine.post("/scan/now", null);
    }

    @GetMapping("/analysis/{symbol}")
    public JsonNode analysis(@PathVariable String symbol, @RequestParam(defaultValue = "M5") String tf,
                             @RequestParam(defaultValue = "150") int bars) {
        if (!symbol.matches("[A-Za-z]{6}") || !tf.matches("[A-Z0-9]{2,3}")) throw new IllegalArgumentException("bad symbol/timeframe");
        return engine.get("/analysis/" + symbol.toUpperCase() + "?tf=" + tf + "&bars=" + bars);
    }

    @GetMapping("/news")
    public JsonNode news() {
        return engine.get("/news");
    }
}
