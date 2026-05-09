package com.hentai.gitmaster.controllers;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
public class HelloController {
    @GetMapping("/status")
    public Map<String, String> getStatus() {
        return Map.of(
                "status", "UP",
                "database", "PostgreSQL 18.3 Connected"
        );
    }
}
