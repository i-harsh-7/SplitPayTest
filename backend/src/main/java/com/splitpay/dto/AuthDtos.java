package com.splitpay.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

/**
 * Request bodies for the auth endpoints. Validated declaratively via {@code @Valid} at the
 * controller boundary (see AuthController) instead of ad-hoc {@code if (blank)} checks in the
 * service layer.
 */
public final class AuthDtos {

    private AuthDtos() {
    }

    /** At least 8 characters, with at least one letter and one digit. */
    static final String PASSWORD_PATTERN = "^(?=.*[A-Za-z])(?=.*\\d).{8,}$";
    static final String PASSWORD_MESSAGE =
            "Password must be at least 8 characters and include at least one letter and one number";

    public record SignUpRequest(
            @NotBlank(message = "Name is required") String name,
            @NotBlank(message = "Email is required") @Email(message = "Email must be a valid address") String email,
            String phone,
            @NotBlank(message = "Password is required")
            @Pattern(regexp = PASSWORD_PATTERN, message = PASSWORD_MESSAGE) String password) {
    }

    public record LoginRequest(
            @NotBlank(message = "Email is required") @Email(message = "Email must be a valid address") String email,
            @NotBlank(message = "Password is required") String password) {
    }

    public record UpdateProfileRequest(
            @NotBlank(message = "Name is required") String name) {
    }

    public record ChangePasswordRequest(
            @NotBlank(message = "Old password is required") String oldPassword,
            @NotBlank(message = "New password is required")
            @Pattern(regexp = PASSWORD_PATTERN, message = PASSWORD_MESSAGE) String newPassword) {
    }
}
