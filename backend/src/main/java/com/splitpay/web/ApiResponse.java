package com.splitpay.web;

import java.util.LinkedHashMap;

/**
 * Tiny builder for the JSON envelopes the controllers return. Using an insertion-ordered map keeps
 * the key order stable and readable (success, message, then payload), and lets us match the exact
 * key names the Flutter client expects — including quirks like the "allAssigments" misspelling.
 */
public final class ApiResponse extends LinkedHashMap<String, Object> {

    private ApiResponse() {
    }

    public static ApiResponse ok() {
        ApiResponse r = new ApiResponse();
        r.put("success", true);
        return r;
    }

    public static ApiResponse success(String message) {
        ApiResponse r = ok();
        r.put("message", message);
        return r;
    }

    /** Fluent put that returns {@code this} so calls can be chained. */
    public ApiResponse with(String key, Object value) {
        put(key, value);
        return this;
    }
}
