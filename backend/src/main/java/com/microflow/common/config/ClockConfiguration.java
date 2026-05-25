package com.microflow.common.config;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.inject.Produces;
import jakarta.inject.Singleton;
import java.time.Clock;

@ApplicationScoped
public class ClockConfiguration {

    @Produces
    @Singleton
    Clock systemClock() {
        return Clock.systemUTC();
    }
}
