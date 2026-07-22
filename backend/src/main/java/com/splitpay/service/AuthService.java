package com.splitpay.service;

import com.splitpay.dto.AuthDtos.ChangePasswordRequest;
import com.splitpay.dto.AuthDtos.LoginRequest;
import com.splitpay.dto.AuthDtos.SignUpRequest;
import com.splitpay.dto.AuthDtos.UpdateProfileRequest;
import com.splitpay.exception.ApiException;
import com.splitpay.model.User;
import com.splitpay.repository.UserRepository;
import com.splitpay.security.JwtService;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.time.Instant;

/**
 * Auth logic ported from controllers/authController.js: signup, login, profile update, password
 * change and fetching the current user. Behaviour (validation, status codes, messages) matches the
 * original.
 */
@Service
public class AuthService {

    /** Account locks after this many consecutive failed login attempts. */
    private static final int MAX_FAILED_LOGIN_ATTEMPTS = 5;
    /** Lock duration once the threshold above is hit. */
    private static final Duration LOCKOUT_DURATION = Duration.ofMinutes(15);

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;

    public AuthService(UserRepository userRepository, PasswordEncoder passwordEncoder, JwtService jwtService) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.jwtService = jwtService;
    }

    /** Result of signup/login: the persisted user plus a freshly minted JWT. */
    public record AuthResult(User user, String token) {
    }

    public AuthResult signUp(SignUpRequest req) {
        if (userRepository.existsByEmail(req.email())) {
            throw ApiException.badRequest("the user already exists");
        }
        String hash = passwordEncoder.encode(req.password());
        User newUser = userRepository.save(User.builder()
                .name(req.name())
                .email(req.email())
                .phone(req.phone())
                .password(hash)
                .build());
        String token = jwtService.generateToken(newUser.getId(), newUser.getTokenVersion());
        return new AuthResult(newUser, token);
    }

    public AuthResult login(LoginRequest req) {
        User user = userRepository.findByEmail(req.email())
                .orElseThrow(() -> ApiException.badRequest("invalid credentials"));

        if (user.getLockedUntil() != null && user.getLockedUntil().isAfter(Instant.now())) {
            throw ApiException.tooManyRequests(
                    "Account temporarily locked due to repeated failed login attempts. Please try again later.");
        }

        if (!passwordEncoder.matches(req.password(), user.getPassword())) {
            registerFailedLogin(user);
            throw ApiException.badRequest("Invalid credentials");
        }

        if (user.getFailedLoginAttempts() != 0 || user.getLockedUntil() != null) {
            user.setFailedLoginAttempts(0);
            user.setLockedUntil(null);
            userRepository.save(user);
        }

        String token = jwtService.generateToken(user.getId(), user.getTokenVersion());
        return new AuthResult(user, token);
    }

    /**
     * Bumps the user's tokenVersion so every previously issued JWT (including the one used to call
     * this endpoint) stops verifying. There's no server-side session/token store to revoke a single
     * token, so logout here means "sign out of all devices" rather than just this one.
     */
    public void logout(String userId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> ApiException.notFound("User not found"));
        user.setTokenVersion(user.getTokenVersion() + 1);
        userRepository.save(user);
    }

    private void registerFailedLogin(User user) {
        int attempts = user.getFailedLoginAttempts() + 1;
        user.setFailedLoginAttempts(attempts);
        if (attempts >= MAX_FAILED_LOGIN_ATTEMPTS) {
            user.setLockedUntil(Instant.now().plus(LOCKOUT_DURATION));
        }
        userRepository.save(user);
    }

    public User updateProfile(UpdateProfileRequest req, String userId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> ApiException.notFound("User not found"));
        user.setName(req.name());
        return userRepository.save(user);
    }

    public void changePassword(ChangePasswordRequest req, String userId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> ApiException.notFound("User not found"));
        if (!passwordEncoder.matches(req.oldPassword(), user.getPassword())) {
            throw ApiException.badRequest("Old password is incorrect");
        }
        user.setPassword(passwordEncoder.encode(req.newPassword()));
        // Invalidate every token issued before this change, so a stolen bearer token stops
        // working the moment the legitimate owner changes their password.
        user.setTokenVersion(user.getTokenVersion() + 1);
        userRepository.save(user);
    }

    public User getUserDetails(String userId) {
        return userRepository.findById(userId)
                .orElseThrow(() -> ApiException.notFound("User not found"));
    }
}
