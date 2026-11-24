package com.microflow.agent.runtime;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.microflow.agent.runtime.application.ConnectorResolver;
import com.microflow.agent.runtime.domain.model.AgentConnector;
import com.microflow.agent.runtime.domain.model.ConnectorKind;
import com.microflow.agent.runtime.domain.model.ConnectorSharingScope;
import com.microflow.agent.runtime.domain.model.ConnectorStatus;
import com.microflow.agent.runtime.domain.tool.ToolContext;
import com.microflow.agent.runtime.infrastructure.connector.ConnectorHttpClient;
import com.microflow.agent.runtime.infrastructure.persistence.JdbcConnectorRepository;
import com.microflow.agent.runtime.infrastructure.tool.CalendarCreateEventTool;
import com.microflow.agent.runtime.infrastructure.tool.WebdavWriteTool;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;

/** Only credential storage is replaced; resolution, rendering and HTTP are real. */
class DavToolProtocolTests {
    private static final Map<String, Object> EVENT = Map.of("summary", "Local review", "start", "2026-11-24T01:00:00Z");

    @Test void samePersistedApprovalUsesSameCalendarUidAcrossToolInstances() throws Exception {
        try (var peer = new DavProtocolTestSupport.DavServer(false, 201)) {
            var resolver = resolver(ConnectorKind.CALDAV, peer.baseUrl());
            var first = new CalendarCreateEventTool(resolver, new ConnectorHttpClient()).invoke(context("approval-001"), EVENT);
            var second = new CalendarCreateEventTool(resolver, new ConnectorHttpClient()).invoke(context("approval-001"), EVENT);
            var different = new CalendarCreateEventTool(resolver, new ConnectorHttpClient()).invoke(context("approval-002"), EVENT);
            assertThat(first.success()).isTrue();
            assertThat(second.success()).isTrue();
            assertThat(different.success()).isTrue();
            assertThat(peer.requests).hasSize(3);
            assertThat(second.output().get("uid")).isEqualTo(first.output().get("uid"));
            assertThat(second.output().get("href")).isEqualTo(first.output().get("href"));
            assertThat(peer.requests.get(1).target()).isEqualTo(peer.requests.get(0).target());
            assertThat(different.output().get("uid")).isNotEqualTo(first.output().get("uid"));
            assertThat(peer.requests.get(2).target()).isNotEqualTo(peer.requests.get(0).target());
        }
    }

    @Test void missingCalendarSummaryIsFailedBeforeAnyPut() throws Exception {
        try (var peer = new DavProtocolTestSupport.DavServer(false, 201)) {
            var tool = new CalendarCreateEventTool(resolver(ConnectorKind.CALDAV, peer.baseUrl()), new ConnectorHttpClient());
            var result = tool.invoke(context("approval-001"), Map.of("start", "2026-11-24T01:00:00Z"));
            assertThat(result.success()).isFalse();
            assertThat(result.uncertain()).isFalse();
            assertThat(peer.requests).isEmpty();
        }
    }

    @Test void malformedCalendarTimeIsFailedBeforeAnyPut() throws Exception {
        try (var peer = new DavProtocolTestSupport.DavServer(false, 201)) {
            var tool = new CalendarCreateEventTool(resolver(ConnectorKind.CALDAV, peer.baseUrl()), new ConnectorHttpClient());
            var result = tool.invoke(context("approval-001"), Map.of("summary", "Bad time", "start", "yesterday"));
            assertThat(result.success()).isFalse();
            assertThat(result.uncertain()).isFalse();
            assertThat(peer.requests).isEmpty();
        }
    }

    @Test void calendarWithoutApprovalCannotPut() throws Exception {
        try (var peer = new DavProtocolTestSupport.DavServer(false, 201)) {
            var tool = new CalendarCreateEventTool(resolver(ConnectorKind.CALDAV, peer.baseUrl()), new ConnectorHttpClient());
            var result = tool.invoke(context(null), EVENT);
            assertThat(result.success()).isFalse();
            assertThat(result.uncertain()).isFalse();
            assertThat(peer.requests).isEmpty();
        }
    }

    @Test void missingWebdavPathIsFailedBeforeAnyPut() throws Exception {
        try (var peer = new DavProtocolTestSupport.DavServer(false, 201)) {
            var tool = new WebdavWriteTool(resolver(ConnectorKind.WEBDAV, peer.baseUrl()), new ConnectorHttpClient());
            var result = tool.invoke(context("approval-001"), Map.of("content", "Fixture text"));
            assertThat(result.success()).isFalse();
            assertThat(result.uncertain()).isFalse();
            assertThat(peer.requests).isEmpty();
        }
    }

    @Test void malformedWebdavUrlRemainsDefiniteFailure() {
        var tool = new WebdavWriteTool(resolver(ConnectorKind.WEBDAV, "http://[bad-host"), new ConnectorHttpClient());
        var result = tool.invoke(context("approval-001"), Map.of("path", "review.txt", "content", "Fixture text"));
        assertThat(result.success()).isFalse();
        assertThat(result.uncertain()).isFalse();
    }

    @Test void explicitDavRejectionsRemainDefiniteFailures() throws Exception {
        try (var peer = new DavProtocolTestSupport.DavServer(false, 403)) {
            var calendar = new CalendarCreateEventTool(resolver(ConnectorKind.CALDAV, peer.baseUrl()), new ConnectorHttpClient())
                    .invoke(context("approval-001"), EVENT);
            var webdav = new WebdavWriteTool(resolver(ConnectorKind.WEBDAV, peer.baseUrl()), new ConnectorHttpClient())
                    .invoke(context("approval-002"), Map.of("path", "review.txt", "content", "Fixture text"));
            assertThat(calendar.success()).isFalse();
            assertThat(calendar.uncertain()).isFalse();
            assertThat(webdav.success()).isFalse();
            assertThat(webdav.uncertain()).isFalse();
            assertThat(peer.requests).hasSize(2);
        }
    }

    private static ToolContext context(String approvalId) {
        return new ToolContext("run-001", "workspace-001", "task-001", null, "owner-001", "assistant", approvalId);
    }

    private static ConnectorResolver resolver(ConnectorKind kind, String baseUrl) {
        var repository = mock(JdbcConnectorRepository.class);
        var connector = new AgentConnector("connector-001", "workspace-001", "owner-001", kind, "Fixture",
                Map.of("baseUrl", baseUrl), List.of("username", "password"), ConnectorSharingScope.PRIVATE,
                List.of(), List.of(), ConnectorStatus.ACTIVE, true, true, null, null, "2026-11-24", "2026-11-24");
        when(repository.listByWorkspace("workspace-001")).thenReturn(List.of(connector));
        when(repository.findCredentials("connector-001")).thenReturn(Map.of("username", "fixture", "password", "test-only"));
        return new ConnectorResolver(repository);
    }
}
