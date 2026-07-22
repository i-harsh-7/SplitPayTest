package com.splitpay;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.data.mongodb.config.EnableMongoAuditing;

/**
 * Entry point for the SplitPay backend.
 *
 * <p>This is a Spring Boot port of the original Node.js/Express service. It keeps the same
 * MongoDB data model, the same JWT auth scheme and — most importantly — the exact same JSON
 * request/response contract so the existing Flutter client keeps working unchanged.
 */
@SpringBootApplication
@EnableMongoAuditing // populates createdAt / updatedAt like Mongoose's { timestamps: true }
public class SplitPayApplication {

    public static void main(String[] args) {
        SpringApplication.run(SplitPayApplication.class, args);
    }
}
