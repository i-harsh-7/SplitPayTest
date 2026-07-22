package com.splitpay.config;

import lombok.Data;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

/**
 * Strongly-typed view of the {@code splitpay.*} configuration block (see application.yml),
 * which in turn is fed by the existing backend/.env values.
 */
@Component
@ConfigurationProperties(prefix = "splitpay")
@Data
public class SplitPayProperties {

    private final Jwt jwt = new Jwt();
    private final Gemini gemini = new Gemini();
    private final Uploads uploads = new Uploads();
    private final Cors cors = new Cors();
    private final Security security = new Security();

    @Data
    public static class Jwt {
        private String secret;
        private long expirationMs = 36_000_000L; // 10h
    }

    @Data
    public static class Gemini {
        private String apiKey;
        private String url;
    }

    @Data
    public static class Uploads {
        private String dir = "uploads";

        /**
         * Per-user cap on /bills/upload calls per hour. Each call makes a paid Gemini Vision
         * request, so this exists independently of the generic per-IP rate limiter to stop a
         * single account from running up the API bill (an attacker can rotate IPs but not
         * accounts without also defeating auth).
         */
        private int rateLimitPerHour = 20;
    }

    @Data
    public static class Cors {
        /**
         * Comma-separated list of allowed origins. Defaults to "*" (dev-friendly) but should be
         * set to the actual Flutter app origin in production via the ALLOWED_ORIGINS env var,
         * which is mapped through application.yml splitpay.cors.allowed-origins.
         */
        private String allowedOrigins = "*";
    }

    @Data
    public static class Security {
        /**
         * Whether to trust the X-Forwarded-For header for client-IP-based rate limiting. Defaults
         * to false: the header is trivially spoofable by any client, so unless a proxy you control
         * sits in front of this app and overwrites (not appends to) the header, honoring it lets an
         * attacker bypass rate limiting entirely by sending a different value on every request. Only
         * set TRUST_PROXY=true when such a proxy is guaranteed to be the sole entry point.
         */
        private boolean trustProxy = false;
    }
}
