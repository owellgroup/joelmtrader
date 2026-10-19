package com.wayaspot.forexbot.web;

import com.wayaspot.forexbot.service.EventService;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

/** Engine -> API callbacks. Protected by the X-Internal-Key header (never exposed to the app). */
@RestController
@RequestMapping("/internal")
public class InternalController {
    private final EventService events;

    public InternalController(EventService events) {
        this.events = events;
    }

    @PostMapping("/events")
    public Map<String, Object> events(@RequestBody Map<String, Object> ev) {
        events.handle(ev);
        return Map.of("ok", true);
    }
}
