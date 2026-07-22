package com.splitpay.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Health/root endpoint, equivalent to {@code app.get("/", ...)} returning "hello jii".
 */
@RestController
public class HomeController {

    @GetMapping("/")
    public String home() {
        return "hello jii";
    }
}
