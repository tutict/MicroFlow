package com.microflow.accounting;

import static org.assertj.core.api.Assertions.assertThat;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.microflow.testing.QuarkusRestTemplate;
import io.quarkus.test.junit.QuarkusTest;
import io.quarkus.test.junit.QuarkusTestProfile;
import io.quarkus.test.junit.TestProfile;
import jakarta.inject.Inject;
import java.io.IOException;
import java.math.BigDecimal;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;

@QuarkusTest
@TestProfile(AccountingApiIntegrationTest.Profile.class)
class AccountingApiIntegrationTest {

    private static final Path databasePath = createDatabasePath();

    public static class Profile implements QuarkusTestProfile {
        @Override
        public Map<String, String> getConfigOverrides() {
            return Map.of(
                    "microflow.database.path", databasePath.toAbsolutePath().toString(),
                    "microflow.agent.mock-delay", "PT0.01S",
                    "microflow.agent.openclaw-state-dir", databasePath.resolveSibling("missing-qclaw-state").toString(),
                    "microflow.seed.demo-enabled", "true",
                    "microflow.jwt.secret", "accounting-integration-test-jwt-secret-with-entropy",
                    "microflow.crypto.secret", "ZmVkY2JhOTg3NjU0MzIxMGZlZGNiYTk4NzY1NDMyMTA="
            );
        }
    }

    @AfterAll
    static void cleanDatabase() {
        try {
            Files.deleteIfExists(databasePath);
        } catch (IOException ignored) {
            // Windows may still hold the SQLite file handle briefly after shutdown.
        }
    }

    private final QuarkusRestTemplate restTemplate = new QuarkusRestTemplate();

    @Inject
    private ObjectMapper objectMapper;

    @Test
    void accountingVoucherCanBePostedAndReportedInTrialBalance() throws Exception {
        var session = loginDemoUser();
        var workspace = firstWorkspace(session.accessToken());
        var cash = createAccount(
                session.accessToken(),
                workspace.id(),
                "1001",
                "Cash",
                "ASSET",
                "DEBIT"
        );
        var revenue = createAccount(
                session.accessToken(),
                workspace.id(),
                "6001",
                "Service revenue",
                "REVENUE",
                "CREDIT"
        );

        var voucherResponse = restTemplate.exchange(
                "/api/v1/workspaces/" + workspace.id() + "/accounting/vouchers",
                HttpMethod.POST,
                authenticatedJsonEntity(session.accessToken(), Map.of(
                        "voucherDate", "2026-05-25",
                        "description", "May service receipt",
                        "lines", List.of(
                                Map.of(
                                        "accountId", cash.get("id"),
                                        "summary", "Cash received",
                                        "debitAmount", new BigDecimal("250.00"),
                                        "creditAmount", BigDecimal.ZERO
                                ),
                                Map.of(
                                        "accountId", revenue.get("id"),
                                        "summary", "Revenue recognized",
                                        "debitAmount", BigDecimal.ZERO,
                                        "creditAmount", new BigDecimal("250.00")
                                )
                        )
                )),
                String.class
        );

        assertThat(voucherResponse.getStatusCode()).isEqualTo(HttpStatus.OK);
        var voucher = readJsonObject(voucherResponse);
        assertThat(voucher.get("status")).isEqualTo("DRAFT");
        assertThat(decimal(voucher.get("totalDebit"))).isEqualByComparingTo("250.00");
        assertThat(decimal(voucher.get("totalCredit"))).isEqualByComparingTo("250.00");

        var postedResponse = restTemplate.exchange(
                "/api/v1/workspaces/" + workspace.id() + "/accounting/vouchers/" + voucher.get("id") + "/post",
                HttpMethod.POST,
                authenticatedEntity(session.accessToken()),
                String.class
        );

        assertThat(postedResponse.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(readJsonObject(postedResponse).get("status")).isEqualTo("POSTED");

        var trialResponse = restTemplate.exchange(
                "/api/v1/workspaces/" + workspace.id() + "/accounting/trial-balance?period=2026-05",
                HttpMethod.GET,
                authenticatedEntity(session.accessToken()),
                String.class
        );

        assertThat(trialResponse.getStatusCode()).isEqualTo(HttpStatus.OK);
        var trialBalance = readJsonList(trialResponse);
        assertThat(trialBalance).anySatisfy(row -> {
            assertThat(row.get("accountCode")).isEqualTo("1001");
            assertThat(decimal(row.get("debitAmount"))).isEqualByComparingTo("250.00");
            assertThat(decimal(row.get("balanceAmount"))).isEqualByComparingTo("250.00");
            assertThat(row.get("balanceDirection")).isEqualTo("DEBIT");
        });
        assertThat(trialBalance).anySatisfy(row -> {
            assertThat(row.get("accountCode")).isEqualTo("6001");
            assertThat(decimal(row.get("creditAmount"))).isEqualByComparingTo("250.00");
            assertThat(decimal(row.get("balanceAmount"))).isEqualByComparingTo("250.00");
            assertThat(row.get("balanceDirection")).isEqualTo("CREDIT");
        });
    }

    @Test
    void accountingVoucherRejectsUnbalancedLines() throws Exception {
        var session = loginDemoUser();
        var workspace = firstWorkspace(session.accessToken());
        var cash = createAccount(
                session.accessToken(),
                workspace.id(),
                "1002",
                "Petty cash",
                "ASSET",
                "DEBIT"
        );
        var revenue = createAccount(
                session.accessToken(),
                workspace.id(),
                "6002",
                "Consulting revenue",
                "REVENUE",
                "CREDIT"
        );

        var response = restTemplate.exchange(
                "/api/v1/workspaces/" + workspace.id() + "/accounting/vouchers",
                HttpMethod.POST,
                authenticatedJsonEntity(session.accessToken(), Map.of(
                        "voucherDate", "2026-05-25",
                        "description", "Unbalanced voucher",
                        "lines", List.of(
                                Map.of(
                                        "accountId", cash.get("id"),
                                        "debitAmount", new BigDecimal("125.00"),
                                        "creditAmount", BigDecimal.ZERO
                                ),
                                Map.of(
                                        "accountId", revenue.get("id"),
                                        "debitAmount", BigDecimal.ZERO,
                                        "creditAmount", new BigDecimal("120.00")
                                )
                        )
                )),
                String.class
        );

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(response.getBody()).contains("Voucher debit and credit totals must balance");
    }

    private Map<String, Object> createAccount(
            String accessToken,
            String workspaceId,
            String code,
            String name,
            String category,
            String normalBalance
    ) throws Exception {
        var response = restTemplate.exchange(
                "/api/v1/workspaces/" + workspaceId + "/accounting/accounts",
                HttpMethod.POST,
                authenticatedJsonEntity(accessToken, Map.of(
                        "code", code,
                        "name", name,
                        "category", category,
                        "normalBalance", normalBalance
                )),
                String.class
        );
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        return readJsonObject(response);
    }

    private AuthSession loginDemoUser() throws Exception {
        var response = restTemplate.postForEntity(
                "/api/v1/auth/login",
                Map.of("email", "demo@microflow.local", "password", "demo12345"),
                String.class
        );

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        var payload = readJsonObject(response);
        return new AuthSession((String) payload.get("accessToken"));
    }

    private WorkspacePayload firstWorkspace(String accessToken) throws Exception {
        var response = restTemplate.exchange(
                "/api/v1/workspaces",
                HttpMethod.GET,
                authenticatedEntity(accessToken),
                String.class
        );

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        var workspaces = readJsonList(response);
        assertThat(workspaces).isNotEmpty();
        var workspace = workspaces.getFirst();
        return new WorkspacePayload((String) workspace.get("id"));
    }

    private HttpEntity<Void> authenticatedEntity(String accessToken) {
        var headers = new HttpHeaders();
        headers.setBearerAuth(accessToken);
        return new HttpEntity<>(headers);
    }

    private HttpEntity<Map<String, Object>> authenticatedJsonEntity(
            String accessToken,
            Map<String, Object> body
    ) {
        var headers = new HttpHeaders();
        headers.setBearerAuth(accessToken);
        headers.setContentType(MediaType.APPLICATION_JSON);
        return new HttpEntity<>(body, headers);
    }

    private Map<String, Object> readJsonObject(ResponseEntity<String> response) throws Exception {
        return readJsonObject(response.getBody());
    }

    private Map<String, Object> readJsonObject(String responseBody) throws Exception {
        return objectMapper.readValue(responseBody, new TypeReference<Map<String, Object>>() {
        });
    }

    private List<Map<String, Object>> readJsonList(ResponseEntity<String> response) throws Exception {
        return objectMapper.readValue(response.getBody(), new TypeReference<List<Map<String, Object>>>() {
        });
    }

    private BigDecimal decimal(Object value) {
        return new BigDecimal(value.toString());
    }

    private static Path createDatabasePath() {
        try {
            var path = Files.createTempFile("microflow-accounting-it-", ".db");
            Files.deleteIfExists(path);
            return path;
        } catch (IOException ex) {
            throw new IllegalStateException("Unable to allocate integration-test database", ex);
        }
    }

    private record AuthSession(String accessToken) {
    }

    private record WorkspacePayload(String id) {
    }
}
