package com.wayaspot.forexbot.service;

import java.time.Instant;

/** Tiny null-safe converters for loosely-typed event payloads. */
public final class Json {
    private Json() { }

    public static Double dbl(Object o) {
        if (o == null) return null;
        if (o instanceof Number n) return n.doubleValue();
        try { return Double.parseDouble(o.toString()); } catch (Exception e) { return null; }
    }

    public static Long lng(Object o) {
        if (o == null) return null;
        if (o instanceof Number n) return n.longValue();
        try { return Long.parseLong(o.toString()); } catch (Exception e) { return null; }
    }

    public static String str(Object o) {
        return o == null ? null : o.toString();
    }

    public static Instant epoch(Object o) {
        Long l = lng(o);
        return l == null ? null : Instant.ofEpochSecond(l);
    }
}
