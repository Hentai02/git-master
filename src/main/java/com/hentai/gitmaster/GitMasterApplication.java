package com.hentai.gitmaster;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
public class GitMasterApplication {

    public static void main(String[] args) {
        SpringApplication.run(GitMasterApplication.class, args);
    }

}
