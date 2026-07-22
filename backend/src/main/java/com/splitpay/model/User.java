package com.splitpay.model;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.annotation.Id;
import org.springframework.data.annotation.LastModifiedDate;
import org.springframework.data.mongodb.core.index.Indexed;
import org.springframework.data.mongodb.core.mapping.Document;

import java.math.BigDecimal;
import java.time.Instant;

/**
 * Mirrors the Mongoose User schema (models/user.js).
 *
 * <p>{@code youOwe} / {@code youAreOwed} are flat running totals, exactly as in the original.
 */
@Document(collection = "users")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class User {

    @Id
    private String id;

    private String name;

    @Indexed(unique = true)
    private String email;

    /** Optional phone number captured at signup. */
    private String phone;

    /** BCrypt hash. Never serialized back to the client (controllers null it out). */
    private String password;

    @Builder.Default
    private BigDecimal youOwe = BigDecimal.ZERO;

    @Builder.Default
    private BigDecimal youAreOwed = BigDecimal.ZERO;

    /**
     * Bumped whenever all outstanding JWTs for this user should be invalidated (password change,
     * logout). Every issued token carries the version it was minted with; the auth filter rejects
     * a token whose version doesn't match the user's current value.
     */
    @Builder.Default
    private int tokenVersion = 0;

    /** Consecutive failed login attempts since the last success; reset on success. */
    @Builder.Default
    private int failedLoginAttempts = 0;

    /** If set and in the future, login is refused regardless of password correctness. */
    private Instant lockedUntil;

    @CreatedDate
    private Instant createdAt;

    @LastModifiedDate
    private Instant updatedAt;
}
