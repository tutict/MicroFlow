// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'MicroFlow';

  @override
  String get language => '语言';

  @override
  String get theme => '主题';

  @override
  String get lightMode => '浅色';

  @override
  String get darkMode => '深色';

  @override
  String get english => '英文';

  @override
  String get simplifiedChinese => '简体中文';

  @override
  String get searchContacts => '搜索联系人';

  @override
  String get signInTitle => '登录 MicroFlow';

  @override
  String get signInDescription => '连接本地工作区，完成认证后开始实时协作。';

  @override
  String get email => '邮箱';

  @override
  String get password => '密码';

  @override
  String get signingIn => '登录中...';

  @override
  String get enterWorkspace => '进入工作区';

  @override
  String restoreSessionError(Object error) {
    return '恢复会话失败：$error';
  }

  @override
  String workspaceLoadError(Object error) {
    return '加载工作区失败：$error';
  }

  @override
  String get signOutTooltip => '退出登录';

  @override
  String get workspaceDescription => '面向本地 AI 执行、加密存储和轻量部署的专注协作工作区。';

  @override
  String get workspace => '工作区';

  @override
  String get workspaceHub => '工作台';

  @override
  String get collaboration => '协作';

  @override
  String get conversations => '会话';

  @override
  String get channels => '频道';

  @override
  String get members => '成员';

  @override
  String get chatTab => '聊天';

  @override
  String get pinnedChannels => '置顶频道';

  @override
  String get automationChannels => '自动化';

  @override
  String get teamChannels => '团队频道';

  @override
  String get contacts => '联系人';

  @override
  String get membersGroup => '成员';

  @override
  String get agentsGroup => '智能体';

  @override
  String contactsCount(int count) {
    return '$count 位联系人';
  }

  @override
  String channelTotal(int count) {
    return '共 $count 个';
  }

  @override
  String conversationCountLabel(int count) {
    return '$count 个会话';
  }

  @override
  String get unreadLabel => '未读';

  @override
  String get directMessages => '私聊';

  @override
  String get agentThreads => '智能体会话';

  @override
  String get previewLabel => '预览';

  @override
  String get memberConversationHint => '1 对 1 团队会话';

  @override
  String get agentConversationHint => '与 AI 协作者的私有会话';

  @override
  String get privateConversationPreview => '私有会话入口已在界面中准备好，后端会话 API 是下一步。';

  @override
  String get localFirst => '本地优先';

  @override
  String get sqlite => 'SQLite';

  @override
  String get virtualThreads => '虚拟线程';

  @override
  String get online => '在线';

  @override
  String activeCountLabel(int count) {
    return '$count 人在线';
  }

  @override
  String messageCountLabel(int count) {
    return '$count 条消息';
  }

  @override
  String get recentActivityLabel => '最近动态';

  @override
  String get recentInteractions => '最近互动';

  @override
  String get noRecentInteractions => '暂时还没有最近互动，团队消息和智能体回复会显示在这里。';

  @override
  String get aiCoworker => 'AI 协作者';

  @override
  String get connected => '已连接';

  @override
  String get connecting => '连接中';

  @override
  String get disconnected => '已断开';

  @override
  String get realtimeError => '实时连接异常';

  @override
  String get idle => '空闲';

  @override
  String get aiEnabled => '已启用 AI';

  @override
  String get chatPanelDescription => '面向团队协作的共享对话流，需要时可通过 @mention 调用智能体。';

  @override
  String get noMessagesTitle => '还没有消息';

  @override
  String get noMessagesDescription => '先发一条团队动态，需要时再 @ 智能体协助处理。';

  @override
  String get quickActionsLabel => '快捷操作';

  @override
  String get pressEnterToSend => '按 Enter 发送';

  @override
  String get sendingMessage => '消息发送中...';

  @override
  String get typeMessageHint => '输入团队消息，需要时使用 @assistant';

  @override
  String membersCountLabel(int count) {
    return '$count 位成员';
  }

  @override
  String get send => '发送';

  @override
  String get sending => '发送中';

  @override
  String messageSendFailed(Object error) {
    return '消息发送失败：$error';
  }

  @override
  String get agents => '智能体';

  @override
  String get availableAgents => '可用智能体';

  @override
  String enabledCount(int count) {
    return '已启用 $count 个';
  }

  @override
  String queueCountLabel(int count) {
    return '$count 个排队中';
  }

  @override
  String get enabled => '启用';

  @override
  String get disabled => '停用';

  @override
  String get runActivity => '运行记录';

  @override
  String get noAgentExecutions => '还没有智能体执行记录。在聊天中 @ 一个智能体即可开始。';

  @override
  String get queued => '排队中';

  @override
  String get running => '运行中';

  @override
  String get completed => '已完成';

  @override
  String get failed => '失败';

  @override
  String executionLabel(Object id) {
    return '执行 $id';
  }

  @override
  String get aiBadge => 'AI';

  @override
  String memberLabel(Object id) {
    return '成员 $id';
  }

  @override
  String get memberYouLabel => '你';

  @override
  String get todayLabel => '今天';

  @override
  String get yesterdayLabel => '昨天';

  @override
  String get agentRunsTitle => '智能体运行';

  @override
  String get recentExecutions => '最近执行';

  @override
  String get collaborationMode => '团队模式';

  @override
  String get collaborationModeHint => '将新的频道消息自动通过 @team 路由给多 Agent 协作。';

  @override
  String collaborationRoundStatus(int round, int total) {
    return '第 $round / $total 轮';
  }

  @override
  String collaborationRunningStatus(Object agentLabel, Object roundLabel) {
    return '$agentLabel 正在协作处理，$roundLabel。';
  }

  @override
  String collaborationCompletedStatus(Object trigger, int totalRounds) {
    return '已通过 $trigger 完成团队协作，共 $totalRounds 轮。';
  }

  @override
  String get collaborationStoppedStatus => '团队协作已停止。';

  @override
  String get summarizeArchitectureChanges => '总结架构变更';

  @override
  String get nativeImagePreflightChecks => '原生镜像预检查';

  @override
  String get cancel => '取消';

  @override
  String get create => '创建';

  @override
  String get add => '添加';

  @override
  String get newWorkspaceTitle => '新建工作区';

  @override
  String get workspaceNameLabel => '工作区名称';

  @override
  String get workspaceNameHint => 'Platform Ops';

  @override
  String get addWorkspaceMemberTitle => '添加工作区成员';

  @override
  String get userEmailLabel => '用户邮箱';

  @override
  String get userEmailHint => 'teammate@microflow.local';

  @override
  String get switchWorkspaceTooltip => '切换工作区';

  @override
  String get knowledgeTooltip => '知识库';

  @override
  String get addMemberTooltip => '添加成员';

  @override
  String get agentDiagnosticsTooltip => '智能体诊断';

  @override
  String get ownerRole => '所有者';

  @override
  String get knowledgeBaseTitle => '知识库';

  @override
  String get refreshTooltip => '刷新';

  @override
  String get uploadFileTooltip => '上传文件';

  @override
  String get uploadTargetLabel => '上传目标';

  @override
  String get workspaceLibrary => '工作区知识库';

  @override
  String uploadTargetConversationDescription(Object conversation) {
    return '新文件会绑定到 $conversation，检索时优先在该会话中使用。';
  }

  @override
  String get uploadTargetWorkspaceDescription => '新文件会作为工作区级知识，在各会话间共享使用。';

  @override
  String get allDocuments => '全部文档';

  @override
  String get workspaceWide => '仅工作区级';

  @override
  String get searchDocumentsHint => '搜索文档';

  @override
  String get referencedSourceNotice => '已高亮显示聊天引用对应的知识来源。';

  @override
  String get knowledgeEmptyDescription => '上传文本、Markdown、JSON 或笔记，为智能体回复提供工作区知识支撑。';

  @override
  String get knowledgeEmptySearchDescription => '当前搜索条件下没有匹配的知识文档。';

  @override
  String snippetsCount(int count) {
    return '$count 个片段';
  }

  @override
  String get referencedSource => '已引用来源';

  @override
  String get teamRunsAvailable => '该会话存在已持久化的团队协作运行记录。';

  @override
  String get history => '历史';

  @override
  String get recentRuns => '最近运行';

  @override
  String get runHistory => '运行历史';

  @override
  String get noRunsMatchFilters => '当前筛选条件下没有匹配的运行记录。';

  @override
  String get filterRuns => '筛选运行';

  @override
  String get allRuns => '全部运行';

  @override
  String get currentRun => '当前运行';

  @override
  String get filterByStatus => '按状态筛选';

  @override
  String get allStatuses => '全部状态';

  @override
  String get stopped => '已停止';

  @override
  String get filterByAgent => '按智能体筛选';

  @override
  String get allAgents => '全部智能体';

  @override
  String get live => '进行中';

  @override
  String eventsCount(int count) {
    return '$count 个事件';
  }

  @override
  String roundsCount(int round, int total) {
    return '第 $round / $total 轮';
  }

  @override
  String reasonLabel(Object reason) {
    return '原因：$reason';
  }

  @override
  String get analyzeStage => '分析';

  @override
  String get critiqueStage => '评审';

  @override
  String get synthesizeStage => '整合';

  @override
  String get deliverStage => '交付';

  @override
  String collaborationStageInProgress(Object stage) {
    return '$stage 进行中';
  }

  @override
  String collaborationStageCompleted(Object stage) {
    return '$stage 已完成';
  }

  @override
  String collaborationStageStopped(Object stage) {
    return '$stage 已停止';
  }

  @override
  String collaborationStageFailed(Object stage) {
    return '$stage 失败';
  }

  @override
  String collaborationStageStatus(Object stage, Object status) {
    return '$stage $status';
  }

  @override
  String get workspaceScopeLabel => '工作区';

  @override
  String get scopedScopeLabel => '局部';
}
