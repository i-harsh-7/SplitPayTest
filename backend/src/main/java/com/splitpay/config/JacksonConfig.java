package com.splitpay.config;

import com.fasterxml.jackson.databind.SerializationFeature;
import org.springframework.boot.autoconfigure.jackson.Jackson2ObjectMapperBuilderCustomizer;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * Money fields are {@link java.math.BigDecimal} throughout the API. Without this, Jackson's
 * default BigDecimal serializer can fall back to scientific notation (e.g. "1E+2") for some
 * values; WRITE_BIGDECIMAL_AS_PLAIN forces plain decimal notation ("100") in every JSON response.
 */
@Configuration
public class JacksonConfig {

    @Bean
    public Jackson2ObjectMapperBuilderCustomizer bigDecimalAsPlainCustomizer() {
        return builder -> builder.featuresToEnable(SerializationFeature.WRITE_BIGDECIMAL_AS_PLAIN);
    }
}
