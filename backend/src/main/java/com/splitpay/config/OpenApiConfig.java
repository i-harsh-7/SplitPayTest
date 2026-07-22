package com.splitpay.config;

import io.swagger.v3.oas.models.Components;
import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.security.SecurityRequirement;
import io.swagger.v3.oas.models.security.SecurityScheme;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * OpenAPI 3 spec metadata, served at /v3/api-docs with Swagger UI at /swagger-ui.html. Registers
 * the bearer JWT scheme so "Authorize" in Swagger UI can exercise authenticated endpoints — every
 * route except {@link com.splitpay.security.JwtAuthFilter#PUBLIC_EXACT_PATHS} requires it.
 */
@Configuration
public class OpenApiConfig {

    private static final String BEARER_SCHEME = "bearerAuth";

    @Bean
    public OpenAPI splitPayOpenApi() {
        return new OpenAPI()
                .info(new Info()
                        .title("SplitPay API")
                        .description("Bill-splitting API: groups, expenses, assignments, invites, notifications.")
                        .version("v1"))
                .addSecurityItem(new SecurityRequirement().addList(BEARER_SCHEME))
                .components(new Components()
                        .addSecuritySchemes(BEARER_SCHEME, new SecurityScheme()
                                .name(BEARER_SCHEME)
                                .type(SecurityScheme.Type.HTTP)
                                .scheme("bearer")
                                .bearerFormat("JWT")));
    }
}
