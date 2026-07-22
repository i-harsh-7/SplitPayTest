package com.splitpay.security;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.splitpay.config.SplitPayProperties;
import com.splitpay.repository.UserRepository;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

import java.util.Arrays;
import java.util.List;

/**
 * Stateless security setup.
 *
 * <p>CORS origins are driven by the {@code ALLOWED_ORIGINS} env var (comma-separated) so you
 * can lock them down per-environment: allow-all for local dev, specific domains in production.
 * Password hashing uses BCrypt strength 10 to match {@code bcrypt.hash(password, 10)} so
 * existing hashes keep verifying.
 */
@Configuration
public class SecurityConfig {

    private final SplitPayProperties properties;

    public SecurityConfig(SplitPayProperties properties) {
        this.properties = properties;
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder(10);
    }

    @Bean
    public JwtAuthFilter jwtAuthFilter(JwtService jwtService, ObjectMapper objectMapper,
                                       UserRepository userRepository) {
        return new JwtAuthFilter(jwtService, objectMapper, userRepository);
    }

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http, JwtAuthFilter jwtAuthFilter) throws Exception {
        http
                .csrf(AbstractHttpConfigurer::disable)
                .cors(cors -> cors.configurationSource(corsConfigurationSource()))
                .sessionManagement(sm -> sm.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .authorizeHttpRequests(auth -> auth
                        .requestMatchers(JwtAuthFilter.PUBLIC_EXACT_PATHS.toArray(new String[0])).permitAll()
                        .requestMatchers(JwtAuthFilter.PUBLIC_PATH_PATTERNS.toArray(new String[0])).permitAll()
                        .anyRequest().authenticated())
                // Our filter both authenticates and writes its own 401 JSON, so disable the default
                // entry points to avoid Spring redirecting to a login page.
                .httpBasic(AbstractHttpConfigurer::disable)
                .formLogin(AbstractHttpConfigurer::disable)
                .addFilterBefore(jwtAuthFilter, UsernamePasswordAuthenticationFilter.class);
        return http.build();
    }

    @Bean
    public CorsConfigurationSource corsConfigurationSource() {
        String rawOrigins = properties.getCors().getAllowedOrigins();
        List<String> origins;
        if (rawOrigins == null || rawOrigins.isBlank() || "*".equals(rawOrigins.trim())) {
            origins = List.of("*");
        } else {
            origins = Arrays.stream(rawOrigins.split(","))
                    .map(String::trim)
                    .filter(s -> !s.isEmpty())
                    .toList();
        }

        CorsConfiguration config = new CorsConfiguration();
        if (origins.size() == 1 && "*".equals(origins.get(0))) {
            config.setAllowedOriginPatterns(List.of("*"));
        } else {
            config.setAllowedOrigins(origins);
            config.setAllowCredentials(true);
        }
        config.setAllowedMethods(List.of("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"));
        config.setAllowedHeaders(List.of("*"));
        config.setMaxAge(3600L);

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", config);
        return source;
    }
}
