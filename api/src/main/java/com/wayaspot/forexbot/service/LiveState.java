package com.wayaspot.forexbot.service;

import com.fasterxml.jackson.databind.JsonNode;
import org.springframework.stereotype.Component;

import java.util.concurrent.atomic.AtomicReference;

/** Latest scan pushed by the engine - lets the dashboard render even if the engine is momentarily busy. */
@Component
public class LiveState {
    private final AtomicReference<Object> scan = new AtomicReference<>();
    private volatile long scanAt = 0;

    public void setScan(Object s) {
        scan.set(s);
        scanAt = System.currentTimeMillis();
    }

    public Object getScan() {
        return scan.get();
    }

    public long getScanAt() {
        return scanAt;
    }
}
