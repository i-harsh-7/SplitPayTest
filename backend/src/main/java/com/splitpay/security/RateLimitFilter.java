package com.splitpay.security;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.splitpay.config.SplitPayProperties;
import jakarta.annotation.PostConstruct;
import jakarta.annotation.PreDestroy;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.MediaType;
import org.springframework.lang.NonNull;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.time.Instant;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;

/**
 * Simple sliding-window rate limiter keyed on the client IP address.
 *
 * <p>Limits:
 * - Auth endpoints (/signUp, /login)  → 10 requests / minute  (brute-force guard)
 * - All other endpoints               → 120 requests / minute (general DDoS guard)
 *
 * <p>This is an in-process, non-clustered implementation — good for a single-instance deploy.
 * For multi-instance production, replace with Redis-backed Bucket4j or a gateway-level solution.
 */
@Component
public class RateLimitFilter extends OncePerRequestFilter {

    private static final Logger log = LoggerFactory.getLogger(RateLimitFilter.class);

    private static final int AUTH_LIMIT = 10;
    private static final int GENERAL_LIMIT = 120;
    private static final long WINDOW_MS = 60_000L; // 1 minute

    private final ObjectMapper objectMapper;
    private final boolean trustProxy;

    // ConcurrentHashMap of IP → (windowStartMs, counter)
    private final ConcurrentHashMap<String, long[]> authBuckets = new ConcurrentHashMap<>();
    private final ConcurrentHashMap<String, long[]> generalBuckets = new ConcurrentHashMap<>();

    // Periodically drops buckets that have had no activity for a full window, so the maps stay
    // bounded by the number of *currently active* IPs rather than growing forever.
    private final ScheduledExecutorService cleaner = Executors.newSingleThreadScheduledExecutor(r -> {
        Thread t = new Thread(r, "rate-limit-bucket-cleaner");
        t.setDaemon(true);
        return t;
    });

    public RateLimitFilter(ObjectMapper objectMapper, SplitPayProperties properties) {
        this.objectMapper = objectMapper;
        this.trustProxy = properties.getSecurity().isTrustProxy();
    }

    @PostConstruct
    void startCleanup() {
        cleaner.scheduleAtFixedRate(this::pruneStaleBuckets, WINDOW_MS, WINDOW_MS, TimeUnit.MILLISECONDS);
    }

    @PreDestroy
    void stopCleanup() {
        cleaner.shutdownNow();
    }

    private void pruneStaleBuckets() {
        long cutoff = Instant.now().toEpochMilli() - WINDOW_MS;
        authBuckets.entrySet().removeIf(e -> e.getValue()[0] < cutoff);
        generalBuckets.entrySet().removeIf(e -> e.getValue()[0] < cutoff);
    }

    @Override
    protected void doFilterInternal(@NonNull HttpServletRequest request,
                                    @NonNull HttpServletResponse response,
                                    @NonNull FilterChain chain)
            throws ServletException, IOException {

        String ip = resolveIp(request);
        String path = request.getRequestURI();

        boolean isAuthEndpoint = path.equals("/api/v1/login") || path.equals("/api/v1/signUp");
        boolean allowed = isAuthEndpoint
                ? checkBucket(authBuckets, ip, AUTH_LIMIT)
                : checkBucket(generalBuckets, ip, GENERAL_LIMIT);

        if (!allowed) {
            log.warn("Rate limit exceeded for IP={} path={}", ip, path);
            response.setStatus(429);
            response.setContentType(MediaType.APPLICATION_JSON_VALUE);
            response.setHeader("Retry-After", "60");
            objectMapper.writeValue(response.getWriter(), Map.of(
                    "success", false,
                    "message", "Too many requests. Please try again later."));
            return;
        }

        chain.doFilter(request, response);
    }

    /**
     * Fixed-window counter. Returns true if the request is within the limit, false otherwise.
     * Thread-safe via ConcurrentHashMap + compute-if-present / merge.
     */
    private boolean checkBucket(ConcurrentHashMap<String, long[]> buckets, String ip, int limit) {
        long now = Instant.now().toEpochMilli();
        long[] bucket = buckets.compute(ip, (key, existing) -> {
            if (existing == null || now - existing[0] >= WINDOW_MS) {
                return new long[]{now, 1};
            }
            existing[1]++;
            return existing;
        });
        return bucket[1] <= limit;
    }

    private String resolveIp(HttpServletRequest request) {
        // X-Forwarded-For is client-supplied and trivially spoofable — honoring it unconditionally
        // lets an attacker bypass rate limiting by sending a different value on every request. Only
        // trust it when explicitly configured to sit behind a proxy that overwrites the header.
        if (trustProxy) {
            String forwarded = request.getHeader("X-Forwarded-For");
            if (forwarded != null && !forwarded.isBlank()) {
                return forwarded.split(",")[0].trim();
            }
        }
        return request.getRemoteAddr();
    }
}
