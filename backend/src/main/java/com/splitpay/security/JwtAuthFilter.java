package com.splitpay.security;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.splitpay.repository.UserRepository;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.http.MediaType;
import org.springframework.lang.NonNull;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.AuthorityUtils;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.util.AntPathMatcher;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.Map;
import java.util.Set;

/**
 * Reproduces the Express {@code auth} middleware (middleware/auth.js).
 *
 * <p>For protected routes it reads the {@code Authorization: Bearer <token>} header, verifies the
 * JWT and stores the user id in the security context (the equivalent of {@code req.user = { id }}).
 * On any failure it returns {@code 401 { success:false, message:"Invalid token. Access denied" }},
 * matching the original response body.
 *
 * <p>Public routes (login / signup / health) are skipped via {@link #shouldNotFilter}.
 */
public class JwtAuthFilter extends OncePerRequestFilter {

    /**
     * Routes that never require a bearer token. Kept as the single source of truth here —
     * {@link com.splitpay.security.SecurityConfig} reads this same set so the two layers (this
     * filter's own gate, and Spring Security's authorizeHttpRequests) can't drift apart.
     */
    public static final Set<String> PUBLIC_EXACT_PATHS = Set.of("/", "/api/v1/login", "/api/v1/signUp");
    public static final Set<String> PUBLIC_PATH_PATTERNS = Set.of(
            "/actuator/health/**", "/v3/api-docs/**", "/swagger-ui/**", "/swagger-ui.html");

    private static final AntPathMatcher PATH_MATCHER = new AntPathMatcher();

    private final JwtService jwtService;
    private final ObjectMapper objectMapper;
    private final UserRepository userRepository;

    public JwtAuthFilter(JwtService jwtService, ObjectMapper objectMapper, UserRepository userRepository) {
        this.jwtService = jwtService;
        this.objectMapper = objectMapper;
        this.userRepository = userRepository;
    }

    @Override
    protected boolean shouldNotFilter(@NonNull HttpServletRequest request) {
        String path = request.getRequestURI();
        return PUBLIC_EXACT_PATHS.contains(path)
                || PUBLIC_PATH_PATTERNS.stream().anyMatch(pattern -> PATH_MATCHER.match(pattern, path));
    }

    @Override
    protected void doFilterInternal(@NonNull HttpServletRequest request,
                                    @NonNull HttpServletResponse response,
                                    @NonNull FilterChain filterChain)
            throws ServletException, IOException {

        String header = request.getHeader("Authorization");

        // The original blew up with a 401 if the Authorization header was missing entirely
        // (it called .replace on undefined), so an absent/!Bearer header is "Invalid token".
        if (header == null || !header.startsWith("Bearer ")) {
            writeUnauthorized(response, "Invalid token. Access denied");
            return;
        }

        String token = header.substring("Bearer ".length()).trim();
        if (token.isEmpty()) {
            writeUnauthorized(response, "No token provided");
            return;
        }

        try {
            JwtService.TokenClaims claims = jwtService.parseToken(token);
            // Reject tokens minted before the user's most recent password change/logout: bumping
            // tokenVersion is our revocation mechanism since JWTs otherwise remain valid until
            // they expire, regardless of what happens to the account afterwards.
            boolean revoked = userRepository.findById(claims.userId())
                    .map(u -> u.getTokenVersion() != claims.tokenVersion())
                    .orElse(true);
            if (revoked) {
                writeUnauthorized(response, "Invalid token. Access denied");
                return;
            }
            var authentication = new UsernamePasswordAuthenticationToken(
                    claims.userId(), null, AuthorityUtils.NO_AUTHORITIES);
            SecurityContextHolder.getContext().setAuthentication(authentication);
        } catch (Exception ex) {
            writeUnauthorized(response, "Invalid token. Access denied");
            return;
        }

        filterChain.doFilter(request, response);
    }

    private void writeUnauthorized(HttpServletResponse response, String message) throws IOException {
        response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        objectMapper.writeValue(response.getWriter(), Map.of(
                "success", false,
                "message", message));
    }
}
