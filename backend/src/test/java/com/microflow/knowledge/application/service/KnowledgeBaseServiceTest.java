package com.microflow.knowledge.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.microflow.chat.infrastructure.persistence.JdbcMessageRepository;
import com.microflow.knowledge.domain.model.KnowledgeChunk;
import com.microflow.knowledge.infrastructure.persistence.JdbcKnowledgeRepository;
import com.microflow.realtime.broadcaster.RealtimeBroadcaster;
import com.microflow.workspace.infrastructure.persistence.JdbcWorkspaceRepository;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockMultipartFile;

class KnowledgeBaseServiceTest {

    @Test
    void chunkTextSplitsLargeBodiesIntoSearchableSlices() {
        var service = new KnowledgeBaseService(
                mock(JdbcKnowledgeRepository.class),
                mock(JdbcWorkspaceRepository.class),
                mock(JdbcMessageRepository.class),
                mock(RealtimeBroadcaster.class),
                Clock.fixed(Instant.parse("2026-04-13T00:00:00Z"), ZoneOffset.UTC),
                "./build/test-data",
                5_242_880,
                3
        );

        var content = """
                Build pipeline rollout checklist with staging verification.

                Capture agent orchestration topology, fallback routing, and retry budget.

                Upload release notes, runbook links, and knowledge handoff details for support.

                Validate workspace ownership transitions and shared document permissions.
                """.repeat(6);

        var chunks = service.chunkText(content);

        assertThat(chunks).hasSizeGreaterThan(1);
        assertThat(chunks).allSatisfy(chunk -> assertThat(chunk).isNotBlank());
        assertThat(chunks.getFirst()).contains("Build pipeline rollout checklist");
    }

    @Test
    void buildContextBlockPrefersCurrentChannelAndRecencyAndReturnsCitations() {
        var knowledgeRepository = mock(JdbcKnowledgeRepository.class);
        when(knowledgeRepository.listChunks("ws_1", 80)).thenReturn(List.of(
                new KnowledgeChunk(
                        "doc_old",
                        "legacy-release.md",
                        "chn_other",
                        "Legacy rollout notes with deployment checklist and approvals.",
                        0,
                        "2026-04-10T00:00:00Z",
                        "2026-04-10T00:00:00Z"
                ),
                new KnowledgeChunk(
                        "doc_recent",
                        "channel-playbook.md",
                        "chn_current",
                        "Deployment checklist for workspace onboarding, rollout gates, and member invites.",
                        0,
                        "2026-04-13T00:00:00Z",
                        "2026-04-13T00:00:00Z"
                )
        ));

        var service = new KnowledgeBaseService(
                knowledgeRepository,
                mock(JdbcWorkspaceRepository.class),
                mock(JdbcMessageRepository.class),
                mock(RealtimeBroadcaster.class),
                Clock.fixed(Instant.parse("2026-04-13T06:00:00Z"), ZoneOffset.UTC),
                "./build/test-data",
                5_242_880,
                2
        );

        var context = service.buildContextBlock(
                "ws_1",
                "chn_current",
                "Need onboarding rollout checklist"
        );

        assertThat(context).contains("Relevant workspace sources:");
        assertThat(context).contains("[kb:doc_recent] channel-playbook.md");
        assertThat(context).contains("cite them inline as [kb:documentId]");
    }

    @Test
    void uploadDocumentRejectsBinaryFiles() {
        var workspaceRepository = mock(JdbcWorkspaceRepository.class);
        when(workspaceRepository.isWorkspaceMember("ws_1", "usr_1")).thenReturn(true);

        var service = new KnowledgeBaseService(
                mock(JdbcKnowledgeRepository.class),
                workspaceRepository,
                mock(JdbcMessageRepository.class),
                mock(RealtimeBroadcaster.class),
                Clock.fixed(Instant.parse("2026-04-13T00:00:00Z"), ZoneOffset.UTC),
                "./build/test-data",
                5_242_880,
                3
        );

        var file = new MockMultipartFile(
                "file",
                "artifact.txt",
                "text/plain",
                new byte[] {1, 2, 0, 4}
        );

        assertThatThrownBy(() -> service.uploadDocument("ws_1", "usr_1", "chn_1", file))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("Binary files are not supported");
    }
}
