package com.splitpay.security;

import com.splitpay.config.SplitPayProperties;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.springframework.stereotype.Service;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.util.Date;

/**
 * Signs and verifies JWTs.
 *
 * <p>Mirrors the Node service which signed {@code { id: user._id }} with {@code JWT_SECRET} and a
 * 10h expiry using HS256. The token payload here is identical: a single "id" claim holding the
 * user's Mongo id, so any tokens issued/consumed look the same to the client.
 */
@Service
public class JwtService {

    private final SecretKey key;
    private final long expirationMs;

    public JwtService(SplitPayProperties properties) {
        String secret = properties.getJwt().getSecret();
        // HS256 requires a key of at least 256 bits (32 bytes). Fail fast with a clear message
        // rather than letting Keys.hmacShaKeyFor throw an opaque WeakKeyException, or — worse —
        // silently running on a short/empty secret.
        if (secret == null || secret.getBytes(StandardCharsets.UTF_8).length < 32) {
            throw new IllegalStateException(
                    "JWT_SECRET must be set and at least 32 characters (256 bits) for HS256. "
                            + "Configure splitpay.jwt.secret / the JWT_SECRET environment variable.");
        }
        this.key = Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
        this.expirationMs = properties.getJwt().getExpirationMs();
    }

    /** Claims carried by a token: the user id plus the token-version it was minted against. */
    public record TokenClaims(String userId, int tokenVersion) {}

    /**
     * Issues a token carrying the user id ("id") and the user's current {@code tokenVersion} ("tv").
     * The version lets us revoke every previously-issued token for a user (password change, logout)
     * without needing a server-side token blocklist: bump the user's stored version and any token
     * minted with an older value stops verifying, even though it hasn't expired yet.
     */
    public String generateToken(String userId, int tokenVersion) {
        Date now = new Date();
        Date expiry = new Date(now.getTime() + expirationMs);
        return Jwts.builder()
                .claim("id", userId)
                .claim("tv", tokenVersion)
                .issuedAt(now)
                .expiration(expiry)
                .signWith(key)
                .compact();
    }

    /** Verifies signature + expiry and returns the id/tokenVersion claims. */
    public TokenClaims parseToken(String token) {
        Claims claims = Jwts.parser()
                .verifyWith(key)
                .build()
                .parseSignedClaims(token)
                .getPayload();
        String userId = claims.get("id", String.class);
        Integer tokenVersion = claims.get("tv", Integer.class);
        return new TokenClaims(userId, tokenVersion == null ? 0 : tokenVersion);
    }
}
