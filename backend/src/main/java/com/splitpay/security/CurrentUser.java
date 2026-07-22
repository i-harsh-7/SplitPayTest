package com.splitpay.security;

import com.splitpay.exception.ApiException;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;

/**
 * Convenience accessor for the authenticated user's id — the analogue of {@code req.user.id} in the
 * original controllers. The id was placed in the security context by {@link JwtAuthFilter}.
 */
public final class CurrentUser {

    private CurrentUser() {
    }

    public static String id() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || auth.getPrincipal() == null) {
            throw new ApiException(HttpStatus.UNAUTHORIZED, "Invalid token. Access denied");
        }
        return auth.getPrincipal().toString();
    }
}
