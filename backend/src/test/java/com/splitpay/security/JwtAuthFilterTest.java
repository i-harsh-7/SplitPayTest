package com.splitpay.security;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.splitpay.model.User;
import com.splitpay.repository.UserRepository;
import jakarta.servlet.FilterChain;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.core.context.SecurityContextHolder;

import java.io.PrintWriter;
import java.io.StringWriter;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Regression test for the JWT revocation mechanism: a token minted with a stale tokenVersion (i.e.
 * issued before a password change or logout) must be rejected even though it hasn't expired,
 * because that's the only way "logout" and "password change invalidates other sessions" work
 * without a server-side token blocklist.
 */
@ExtendWith(MockitoExtension.class)
class JwtAuthFilterTest {

    @Mock private JwtService jwtService;
    @Mock private UserRepository userRepository;
    @Mock private HttpServletRequest request;
    @Mock private HttpServletResponse response;
    @Mock private FilterChain filterChain;

    private JwtAuthFilter filter;

    @BeforeEach
    void setUp() {
        filter = new JwtAuthFilter(jwtService, new ObjectMapper(), userRepository);
    }

    @AfterEach
    void clearContext() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void doFilterInternal_rejectsTokenWithStaleTokenVersion() throws Exception {
        when(request.getHeader("Authorization")).thenReturn("Bearer some-token");
        when(jwtService.parseToken("some-token")).thenReturn(new JwtService.TokenClaims("user-1", 0));
        User current = User.builder().id("user-1").tokenVersion(1).build(); // bumped since token was issued
        when(userRepository.findById("user-1")).thenReturn(Optional.of(current));
        when(response.getWriter()).thenReturn(new PrintWriter(new StringWriter()));

        filter.doFilterInternal(request, response, filterChain);

        verify(response).setStatus(HttpServletResponse.SC_UNAUTHORIZED);
        verify(filterChain, never()).doFilter(request, response);
        assertThat(SecurityContextHolder.getContext().getAuthentication()).isNull();
    }

    @Test
    void doFilterInternal_acceptsTokenWithCurrentTokenVersion() throws Exception {
        when(request.getHeader("Authorization")).thenReturn("Bearer some-token");
        when(jwtService.parseToken("some-token")).thenReturn(new JwtService.TokenClaims("user-1", 1));
        User current = User.builder().id("user-1").tokenVersion(1).build();
        when(userRepository.findById("user-1")).thenReturn(Optional.of(current));

        filter.doFilterInternal(request, response, filterChain);

        verify(filterChain).doFilter(request, response);
        assertThat(SecurityContextHolder.getContext().getAuthentication().getPrincipal()).isEqualTo("user-1");
    }

    @Test
    void doFilterInternal_rejectsTokenForDeletedUser() throws Exception {
        when(request.getHeader("Authorization")).thenReturn("Bearer some-token");
        when(jwtService.parseToken("some-token")).thenReturn(new JwtService.TokenClaims("ghost-user", 0));
        when(userRepository.findById("ghost-user")).thenReturn(Optional.empty());
        when(response.getWriter()).thenReturn(new PrintWriter(new StringWriter()));

        filter.doFilterInternal(request, response, filterChain);

        verify(response).setStatus(HttpServletResponse.SC_UNAUTHORIZED);
        verify(filterChain, never()).doFilter(request, response);
    }
}
