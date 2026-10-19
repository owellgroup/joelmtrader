package com.wayaspot.forexbot;

import com.wayaspot.forexbot.config.AppProps;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.scheduling.annotation.EnableAsync;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableConfigurationProperties(AppProps.class)
@EnableScheduling
@EnableAsync
public class ForexBotApplication {
    public static void main(String[] args) {
        SpringApplication.run(ForexBotApplication.class, args);
    }
}
