package com.microflow.knowledge;

import static org.assertj.core.api.Assertions.assertThat;
import static io.restassured.RestAssured.given;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.microflow.testing.MicroFlowApiTestSupport;
import com.microflow.testing.QuarkusRestTemplate;
import io.quarkus.test.junit.QuarkusTest;
import io.quarkus.test.junit.QuarkusTestProfile;
import io.quarkus.test.junit.TestProfile;
import jakarta.inject.Inject;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;

/** The RESTEasy multipart boundary works without Spring MultipartFile at runtime. */
@QuarkusTest
@TestProfile(KnowledgeUploadHttpTests.Profile.class)
class KnowledgeUploadHttpTests extends MicroFlowApiTestSupport {
    private static final Path DIRECTORY = temporaryDirectory();
    private final QuarkusRestTemplate http = new QuarkusRestTemplate();
    @Inject ObjectMapper mapper;

    public static class Profile implements QuarkusTestProfile {
        @Override
        public Map<String, String> getConfigOverrides() {
            return Map.of(
                    "microflow.database.path", DIRECTORY.resolve("knowledge.db").toString(),
                    "MICROFLOW_DATA_DIR", DIRECTORY.resolve("data").toString(),
                    "microflow.agent.openclaw-state-dir", DIRECTORY.resolve("missing-provider").toString(),
                    "microflow.seed.demo-enabled", "false",
                    "microflow.jwt.secret", "knowledge-upload-test-jwt-secret-with-entropy",
                    "microflow.crypto.secret", "ZmVkY2JhOTg3NjU0MzIxMGZlZGNiYTk4NzY1NDMyMTA=");
        }
    }

    @Test
    void aTextMultipartUploadKeepsMetadataContentAndTheDocumentList() {
        var owner = register(http, mapper, "knowledge-" + System.nanoTime() + "@example.com", "Owner");
        var workspaceId = createWorkspace(http, mapper, owner, "Knowledge upload");
        var path = "/api/v1/workspaces/" + workspaceId + "/knowledge-documents";
        var bytes = "# Release checklist\nReview approved actions before shipping.".getBytes(StandardCharsets.UTF_8);
        var contentType = "text/markdown;charset=UTF-8";
        var response = given().auth().oauth2(owner.token())
                .multiPart("file", "release.md", bytes, contentType)
                .post(path).then().statusCode(200).extract().asString();
        var document = readMap(mapper, response);
        assertThat(document).containsEntry("fileName", "release.md")
                .containsEntry("contentType", contentType)
                .containsEntry("sizeBytes", bytes.length);
        assertThat(String.valueOf(document.get("summary"))).contains("Release checklist");
        var list = get(http, path, owner);
        assertThat(list.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(readList(mapper, list.getBody())).singleElement().satisfies(row ->
                assertThat(row.get("id")).isEqualTo(document.get("id")));
    }

    @Test
    void aBinaryMultipartUploadIsRejectedWithoutCreatingADocument() {
        var owner = register(http, mapper, "binary-" + System.nanoTime() + "@example.com", "Owner");
        var workspaceId = createWorkspace(http, mapper, owner, "Rejected upload");
        var path = "/api/v1/workspaces/" + workspaceId + "/knowledge-documents";
        given().auth().oauth2(owner.token()).multiPart("file", "notes.txt", new byte[] {1, 2, 0, 4}, "text/plain")
                .post(path).then().statusCode(400);
        assertThat(readList(mapper, get(http, path, owner).getBody())).isEmpty();
        assertThat(DIRECTORY.resolve("data/knowledge").resolve(workspaceId)).doesNotExist();
    }

    private static Path temporaryDirectory() {
        try { return Files.createTempDirectory("microflow-knowledge-http-").toAbsolutePath(); }
        catch (IOException exception) { throw new IllegalStateException(exception); }
    }
}
