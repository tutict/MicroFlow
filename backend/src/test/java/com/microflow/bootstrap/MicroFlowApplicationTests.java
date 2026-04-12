package com.microflow.bootstrap;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;

@SpringBootTest(properties = {
        "microflow.agent.openclaw-state-dir=missing-qclaw-state",
        "microflow.jwt.secret=test-context-jwt-secret-with-entropy",
        "microflow.crypto.secret=ZmVkY2JhOTg3NjU0MzIxMGZlZGNiYTk4NzY1NDMyMTA="
})
class MicroFlowApplicationTests {

    @Test
    void contextLoads() {
    }
}
