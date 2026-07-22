package com.splitpay.controller;

import com.splitpay.dto.AuthDtos.ChangePasswordRequest;
import com.splitpay.dto.AuthDtos.LoginRequest;
import com.splitpay.dto.AuthDtos.SignUpRequest;
import com.splitpay.dto.AuthDtos.UpdateProfileRequest;
import com.splitpay.security.CurrentUser;
import com.splitpay.service.AuthService;
import com.splitpay.service.ResponseMapper;
import com.splitpay.web.ApiResponse;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

/**
 * Auth + profile endpoints, mounted under /api/v1 to match authRoutes.js.
 */
@RestController
@RequestMapping("/api/v1")
public class AuthController {

    private final AuthService authService;
    private final ResponseMapper responseMapper;

    public AuthController(AuthService authService, ResponseMapper responseMapper) {
        this.authService = authService;
        this.responseMapper = responseMapper;
    }

    @PostMapping("/signUp")
    public ResponseEntity<?> signUp(@Valid @RequestBody SignUpRequest req) {
        AuthService.AuthResult result = authService.signUp(req);
        return ResponseEntity.ok(ApiResponse.success("signed Up successfully")
                .with("token", result.token())
                .with("user", responseMapper.userPublic(result.user())));
    }

    @PostMapping("/login")
    public ResponseEntity<?> login(@Valid @RequestBody LoginRequest req) {
        AuthService.AuthResult result = authService.login(req);
        return ResponseEntity.ok(ApiResponse.success("Logged in  successfully")
                .with("token", result.token())
                .with("user", responseMapper.userPublic(result.user())));
    }

    @PatchMapping("/updateProfile")
    public ResponseEntity<?> updateProfile(@Valid @RequestBody UpdateProfileRequest req) {
        var user = authService.updateProfile(req, CurrentUser.id());
        return ResponseEntity.ok(ApiResponse.success("Profile updated successfully")
                .with("user", responseMapper.userPublic(user)));
    }

    @PatchMapping("/changePassword")
    public ResponseEntity<?> changePassword(@Valid @RequestBody ChangePasswordRequest req) {
        authService.changePassword(req, CurrentUser.id());
        return ResponseEntity.ok(ApiResponse.success("Password changed successfully"));
    }

    /**
     * Invalidates every JWT issued to the current user (there's no per-token store, so this signs
     * out all devices, not just the caller's).
     */
    @PostMapping("/logout")
    public ResponseEntity<?> logout() {
        authService.logout(CurrentUser.id());
        return ResponseEntity.ok(ApiResponse.success("Logged out successfully"));
    }

    @GetMapping("/getUserDetails")
    public ResponseEntity<?> getUserDetails() {
        var user = authService.getUserDetails(CurrentUser.id());
        return ResponseEntity.ok(ApiResponse.success("User details fetched successfully")
                .with("user", responseMapper.userPublic(user)));
    }
}
