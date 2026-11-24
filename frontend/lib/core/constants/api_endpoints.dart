final class ApiEndpoints {
  const ApiEndpoints._();

  static const login = '/auth/login';
  static const refresh = '/auth/refresh';
  static const logout = '/auth/logout';
  static const me = '/auth/me';
  static const webSocketTicket = '/auth/ws-ticket';
  static const workspaces = '/workspaces';
  static const agents = '/agents';
  static const agentRuns = '/agent-runs';
  static const agentDiagnostics = '/agent-diagnostics';

  static String agentRoleStrategy(String agentKey) {
    return '/agents/$agentKey/role-strategy';
  }

  static String channelMessages(String channelId) {
    return '/channels/$channelId/messages';
  }

  static String channelCollaborationHistory(String channelId) {
    return '/channels/$channelId/collaboration-history';
  }

  static String channelCollaborationRuns(String channelId) {
    return '/channels/$channelId/collaboration-runs';
  }

  static String workspaceChannels(String workspaceId) {
    return '/workspaces/$workspaceId/channels';
  }

  static String workspaceConversations(String workspaceId) {
    return '/workspaces/$workspaceId/conversations';
  }

  static String workspaceMembers(String workspaceId) {
    return '/workspaces/$workspaceId/members';
  }

  static String workspaceKnowledgeDocuments(String workspaceId) {
    return '/workspaces/$workspaceId/knowledge-documents';
  }

  static String workspaceAccountingAccounts(String workspaceId) {
    return '/workspaces/$workspaceId/accounting/accounts';
  }

  static String workspaceAccountingVouchers(String workspaceId) {
    return '/workspaces/$workspaceId/accounting/vouchers';
  }

  static String workspaceAccountingVoucherPost(
    String workspaceId,
    String voucherId,
  ) {
    return '/workspaces/$workspaceId/accounting/vouchers/$voucherId/post';
  }

  static String workspaceAccountingTrialBalance(String workspaceId) {
    return '/workspaces/$workspaceId/accounting/trial-balance';
  }

  static String workspaceTaskProjects(String workspaceId) {
    return '/workspaces/$workspaceId/task-projects';
  }

  static String workspaceTasks(String workspaceId) {
    return '/workspaces/$workspaceId/tasks';
  }

  static String workspaceTaskSummary(String workspaceId) {
    return '/workspaces/$workspaceId/task-summary';
  }

  static String workspaceTaskStatus(String workspaceId, String taskId) {
    return '/workspaces/$workspaceId/tasks/$taskId/status';
  }

  static String workspaceTaskAssignee(String workspaceId, String taskId) {
    return '/workspaces/$workspaceId/tasks/$taskId/assignee';
  }

  static String workspaceTaskActivity(String workspaceId, String taskId) {
    return '/workspaces/$workspaceId/tasks/$taskId/activity';
  }

  static String workspaceMyWork(String workspaceId) {
    return '/workspaces/$workspaceId/my-work';
  }

  static String workspaceTaskDecisions(String workspaceId, String taskId) {
    return '/workspaces/$workspaceId/tasks/$taskId/decisions';
  }

  static String workspaceMemberRole(String workspaceId, String userId) {
    return '/workspaces/$workspaceId/members/$userId/role';
  }

  static String workspaceAgentRuns(String workspaceId) {
    return '/workspaces/$workspaceId/agent-runs';
  }

  static String taskAgentRuns(String workspaceId, String taskId) {
    return '/workspaces/$workspaceId/tasks/$taskId/agent-runs';
  }

  static String agentRun(String runId) {
    return '/agent-runs/$runId';
  }

  static String agentRunSteps(String runId) => '/agent-runs/$runId/steps';

  static String agentRunEvents(String runId) {
    return '/agent-runs/$runId/events';
  }

  static String agentRunApprovals(String runId) {
    return '/agent-runs/$runId/approvals';
  }

  static String agentRunContextSources(String runId) {
    return '/agent-runs/$runId/context-sources';
  }

  static String agentRunArtifacts(String runId) {
    return '/agent-runs/$runId/artifacts';
  }

  static String agentApprovalDecision(String runId, String approvalId) {
    return '/agent-runs/$runId/approvals/$approvalId/decision';
  }

  static String agentRunCancel(String runId) {
    return '/agent-runs/$runId/cancel';
  }

  static String agentRunRetry(String runId) {
    return '/agent-runs/$runId/retry';
  }

  static String workspaceConnectors(String workspaceId) {
    return '/workspaces/$workspaceId/connectors';
  }

  static String workspaceConnector(String workspaceId, String connectorId) {
    return '/workspaces/$workspaceId/connectors/$connectorId';
  }

  static String workspaceConnectorTest(String workspaceId, String connectorId) {
    return '/workspaces/$workspaceId/connectors/$connectorId/test';
  }
}
