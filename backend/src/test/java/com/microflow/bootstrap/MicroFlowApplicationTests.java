package com.microflow.bootstrap;

import io.quarkus.test.junit.QuarkusTest;
import io.quarkus.test.junit.QuarkusTestProfile;
import io.quarkus.test.junit.TestProfile;
import java.util.Map;
import org.junit.jupiter.api.Test;

@QuarkusTest
@TestProfile(MicroFlowApplicationTests.Profile.class)
class MicroFlowApplicationTests {

    public static class Profile implements QuarkusTestProfile {
        @Override
        public Map<String, String> getConfigOverrides() {
            return Map.of(
                    "microflow.database.path", "./target/test-context.db",
                    "microflow.agent.openclaw-state-dir", "missing-qclaw-state",
                    "microflow.jwt.secret", "test-context-jwt-secret-with-entropy",
                    "microflow.crypto.secret", "ZmVkY2JhOTg3NjU0MzIxMGZlZGNiYTk4NzY1NDMyMTA="
            );
        }
    }

    @Test
    void contextLoads() {
    }
}
