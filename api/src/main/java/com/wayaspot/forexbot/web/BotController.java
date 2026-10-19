package com.wayaspot.forexbot.web;

import com.fasterxml.jackson.databind.JsonNode;
import com.wayaspot.forexbot.service.BotService;
import com.wayaspot.forexbot.service.EngineClient;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/bot")
public class BotController {
    public record StopRequest(Boolean closePositions) { }

    private final BotService bot;
    private final EngineClient engine;

    public BotController(BotService bot, EngineClient engine) {
        this.bot = bot;
        this.engine = engine;
    }

    @GetMapping("/status")
    public Map<String, Object> status() {
        return bot.status();
    }

    @PostMapping("/start")
    public Map<String, Object> start() {
        return bot.start();
    }

    @PostMapping("/stop")
    public Map<String, Object> stop(@RequestBody(required = false) StopRequest r) {
        return bot.stop(r == null || r.closePositions() == null || r.closePositions());
    }

    @PostMapping("/positions/{ticket}/close")
    public JsonNode closePosition(@PathVariable long ticket) {
        return engine.post("/positions/" + ticket + "/close", null);
    }

    @PostMapping("/positions/close-all")
    public JsonNode closeAll() {
        return engine.post("/positions/close-all", null);
    }
}
