package com.splitpay.service;

import com.splitpay.dto.AuthDtos.ChangePasswordRequest;
import com.splitpay.dto.AuthDtos.LoginRequest;
import com.splitpay.exception.ApiException;
import com.splitpay.model.User;
import com.splitpay.repository.UserRepository;
import com.splitpay.security.JwtService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.time.Instant;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.when;

/**
 * Covers the token-revocation and account-lockout behaviour added to AuthService: password change
 * / logout must bump tokenVersion (so stolen bearer tokens stop working), and repeated failed
 * logins must lock the account independently of the shared IP-based rate limiter.
 */
@ExtendWith(MockitoExtension.class)
class AuthServiceTest {

    @Mock private UserRepository userRepository;
    @Mock private PasswordEncoder passwordEncoder;
    @Mock private JwtService jwtService;

    private AuthService authService;
    private User user;

    @BeforeEach
    void setUp() {
        authService = new AuthService(userRepository, passwordEncoder, jwtService);
        user = User.builder()
                .id("user-1")
                .email("alice@example.com")
                .password("hashed-password")
                .tokenVersion(0)
                .failedLoginAttempts(0)
                .build();
    }

    @Test
    void login_locksAccountAfterFiveFailedAttempts() {
        when(userRepository.findByEmail("alice@example.com")).thenReturn(Optional.of(user));
        when(passwordEncoder.matches(anyString(), anyString())).thenReturn(false);

        LoginRequest req = new LoginRequest("alice@example.com", "wrong-password");
        for (int i = 0; i < 5; i++) {
            assertThatThrownBy(() -> authService.login(req)).isInstanceOf(ApiException.class);
        }

        assertThat(user.getLockedUntil()).isNotNull();
        assertThat(user.getLockedUntil()).isAfter(Instant.now());
    }

    @Test
    void login_rejectsEvenCorrectPasswordWhileLocked() {
        user.setLockedUntil(Instant.now().plusSeconds(600));
        when(userRepository.findByEmail("alice@example.com")).thenReturn(Optional.of(user));

        LoginRequest req = new LoginRequest("alice@example.com", "correct-password");

        assertThatThrownBy(() -> authService.login(req))
                .isInstanceOf(ApiException.class)
                .extracting(ex -> ((ApiException) ex).getStatus())
                .isEqualTo(HttpStatus.TOO_MANY_REQUESTS);
    }

    @Test
    void login_resetsFailedAttemptsOnSuccess() {
        user.setFailedLoginAttempts(3);
        when(userRepository.findByEmail("alice@example.com")).thenReturn(Optional.of(user));
        when(passwordEncoder.matches(anyString(), anyString())).thenReturn(true);
        when(jwtService.generateToken(any(), any(Integer.class))).thenReturn("token");

        authService.login(new LoginRequest("alice@example.com", "correct-password"));

        assertThat(user.getFailedLoginAttempts()).isZero();
    }

    @Test
    void changePassword_bumpsTokenVersionSoStolenTokensStopWorking() {
        when(userRepository.findById("user-1")).thenReturn(Optional.of(user));
        when(passwordEncoder.matches(anyString(), anyString())).thenReturn(true);
        when(passwordEncoder.encode(anyString())).thenReturn("new-hash");

        authService.changePassword(new ChangePasswordRequest("old-password", "new-password1"), "user-1");

        assertThat(user.getTokenVersion()).isEqualTo(1);
    }

    @Test
    void changePassword_locksAccountAfterFiveFailedOldPasswordAttempts() {
        when(userRepository.findById("user-1")).thenReturn(Optional.of(user));
        when(passwordEncoder.matches(anyString(), anyString())).thenReturn(false);

        ChangePasswordRequest req = new ChangePasswordRequest("wrong-old-password", "new-password1");
        for (int i = 0; i < 5; i++) {
            assertThatThrownBy(() -> authService.changePassword(req, "user-1")).isInstanceOf(ApiException.class);
        }

        assertThat(user.getLockedUntil()).isNotNull();
        assertThat(user.getLockedUntil()).isAfter(Instant.now());
    }

    @Test
    void changePassword_rejectsEvenCorrectOldPasswordWhileLocked() {
        user.setLockedUntil(Instant.now().plusSeconds(600));
        when(userRepository.findById("user-1")).thenReturn(Optional.of(user));

        ChangePasswordRequest req = new ChangePasswordRequest("old-password", "new-password1");

        assertThatThrownBy(() -> authService.changePassword(req, "user-1"))
                .isInstanceOf(ApiException.class)
                .extracting(ex -> ((ApiException) ex).getStatus())
                .isEqualTo(HttpStatus.TOO_MANY_REQUESTS);
    }

    @Test
    void logout_bumpsTokenVersion() {
        when(userRepository.findById("user-1")).thenReturn(Optional.of(user));

        authService.logout("user-1");

        assertThat(user.getTokenVersion()).isEqualTo(1);
    }
}
