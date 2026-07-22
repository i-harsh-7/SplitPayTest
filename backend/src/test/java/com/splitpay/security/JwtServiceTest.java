package com.splitpay.security;

import com.splitpay.config.SplitPayProperties;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.junit.jupiter.api.Assertions.assertThrows;

class JwtServiceTest {

    private JwtService jwtService;

    @BeforeEach
    void setUp() {
        SplitPayProperties properties = new SplitPayProperties();
        properties.getJwt().setSecret("this-is-a-32-plus-character-test-secret-value");
        properties.getJwt().setExpirationMs(3_600_000L);
        jwtService = new JwtService(properties);
    }

    @Test
    void generateToken_roundTripsUserIdAndTokenVersion() {
        String token = jwtService.generateToken("user-1", 3);

        JwtService.TokenClaims claims = jwtService.parseToken(token);

        assertThat(claims.userId()).isEqualTo("user-1");
        assertThat(claims.tokenVersion()).isEqualTo(3);
    }

    @Test
    void parseToken_rejectsTamperedSignature() {
        String token = jwtService.generateToken("user-1", 0);
        String tampered = token.substring(0, token.length() - 1) + (token.endsWith("A") ? "B" : "A");

        assertThrows(Exception.class, () -> jwtService.parseToken(tampered));
    }
}
