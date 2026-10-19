package com.wayaspot.forexbot.service;

public class EngineException extends RuntimeException {
    private final int status;

    public EngineException(String message, int status) {
        super(message);
        this.status = status;
    }

    public int getStatus() {
        return status;
    }
}
