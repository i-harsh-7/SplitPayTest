package com.splitpay.security;

import com.splitpay.config.SplitPayProperties;
import com.splitpay.exception.ApiException;
import jakarta.annotation.PostConstruct;
import jakarta.annotation.PreDestroy;
import org.springframework.stereotype.Component;

import java.time.Instant;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;

/**
 * Per-user throttle for /bills/upload specifically. Each call there makes a paid Gemini Vision
 * request, so the generic per-IP limiter in {@link RateLimitFilter} isn't enough on its own — an
 * attacker can spread calls across many source IPs without needing many accounts, but can't spread
 * them across many accounts without also defeating auth. Keyed by user id, not IP.
 */
@Component
public class UploadRateLimiter {

    private static final long WINDOW_MS = 3_600_000L; // 1 hour

    private final int limit;
    private final ConcurrentHashMap<String, long[]> buckets = new ConcurrentHashMap<>();
    private final ScheduledExecutorService cleaner = Executors.newSingleThreadScheduledExecutor(r -> {
        Thread t = new Thread(r, "upload-rate-limit-cleaner");
        t.setDaemon(true);
        return t;
    });

    public UploadRateLimiter(SplitPayProperties properties) {
        this.limit = properties.getUploads().getRateLimitPerHour();
    }

    @PostConstruct
    void startCleanup() {
        cleaner.scheduleAtFixedRate(this::pruneStaleBuckets, WINDOW_MS, WINDOW_MS, TimeUnit.MILLISECONDS);
    }

    @PreDestroy
    void stopCleanup() {
        cleaner.shutdownNow();
    }

    /** Throws 429 if the user has already hit their hourly upload quota this window. */
    public void checkAndRecord(String userId) {
        long now = Instant.now().toEpochMilli();
        long[] bucket = buckets.compute(userId, (key, existing) -> {
            if (existing == null || now - existing[0] >= WINDOW_MS) {
                return new long[]{now, 1};
            }
            existing[1]++;
            return existing;
        });
        if (bucket[1] > limit) {
            throw ApiException.tooManyRequests(
                    "Upload limit reached (" + limit + " per hour). Please try again later.");
        }
    }

    private void pruneStaleBuckets() {
        long cutoff = Instant.now().toEpochMilli() - WINDOW_MS;
        buckets.entrySet().removeIf(e -> e.getValue()[0] < cutoff);
    }
}
