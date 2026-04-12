final class ApiEndpoints {
  const ApiEndpoints._();

  static const login = '/auth/login';
  static const refresh = '/auth/refresh';
  static const me = '/auth/me';
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

  static String workspaceChannels(String workspaceId) {
    return '/workspaces/$workspaceId/channels';
  }

  static String workspaceConversations(String workspaceId) {
    return '/workspaces/$workspaceId/conversations';
  }
}
