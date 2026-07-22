package com.splitpay.security;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.lang.NonNull;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;

/**
 * Adds defensive HTTP response headers on every response:
 * - X-Content-Type-Options: nosniff  — prevents MIME-sniffing attacks
 * - X-Frame-Options: DENY            — prevents clickjacking
 * - Referrer-Policy                  — limits referrer header leakage
 * - Content-Security-Policy          — restricts what the browser can load (API-only: no HTML)
 * - Cache-Control                    — prevents sensitive data being cached
 * - X-XSS-Protection                 — legacy IE XSS filter (belt-and-suspenders)
 */
@Component
public class SecurityHeadersFilter extends OncePerRequestFilter {

    @Override
    protected void doFilterInternal(@NonNull HttpServletRequest request,
                                    @NonNull HttpServletResponse response,
                                    @NonNull FilterChain chain)
            throws ServletException, IOException {

        response.setHeader("X-Content-Type-Options", "nosniff");
        response.setHeader("X-Frame-Options", "DENY");
        response.setHeader("Referrer-Policy", "strict-origin-when-cross-origin");
        response.setHeader("Content-Security-Policy", "default-src 'none'; frame-ancestors 'none'");
        response.setHeader("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0");
        response.setHeader("Pragma", "no-cache");
        response.setHeader("X-XSS-Protection", "1; mode=block");

        chain.doFilter(request, response);
    }
}
