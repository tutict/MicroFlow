// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '微澜协作';

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
  String get signInTitle => '登录';

  @override
  String get signInDescription => '继续进入本地工作区。';

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
  String get workspaceDescription => '会话、成员与智能体，集中协作。';

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
  String get agentConversationHint => '智能体私聊';

  @override
  String get privateConversationPreview => '此会话暂不可用。';

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
  String get chatPanelDescription => '团队会话';

  @override
  String get noMessagesTitle => '还没有消息';

  @override
  String get noMessagesDescription => '发送第一条消息。';

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
  String get agentRunsTitle => 'Agent 运行';

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
  String get knowledgeEmptyDescription => '上传文档后即可使用。';

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

  @override
  String get indexTab => '索引';

  @override
  String get toolsTab => '工具';

  @override
  String get toolsTitle => '工具';

  @override
  String get toolKnowledgeDescription => '打开当前工作区的资料。';

  @override
  String get toolAccountingDescription => '查看科目、凭证和试算平衡。';

  @override
  String get toolDiagnosticsDescription => '检查 Agent 健康状态和角色策略。';

  @override
  String get toolAppearanceDescription => '在浅色和深色之间切换。';

  @override
  String get toolLanguageDescription => '使用中文或英文。';

  @override
  String get toolSignOutDescription => '退出这台设备上的当前工作区。';

  @override
  String get inspectorCurrent => '当前';

  @override
  String get inspectorCollaboration => '协作';

  @override
  String get inspectorKnowledge => '资料';

  @override
  String get backToConversation => '返回会话';

  @override
  String get signOutConfirmTitle => '退出登录？';

  @override
  String get signOutConfirmBody => '将退出这台设备上的当前工作区。';

  @override
  String get openInspectorTooltip => '详情';

  @override
  String get openToolsTooltip => '工具';

  @override
  String get destinationConversation => '会话';

  @override
  String get destinationKnowledge => '知识库';

  @override
  String get destinationAccounting => '会计';

  @override
  String get destinationDiagnostics => '诊断';

  @override
  String get destinationTasks => '任务';

  @override
  String get taskNewTaskHint => '要推进的事情是什么？';

  @override
  String get taskCreateAction => '添加';

  @override
  String get taskCreatePending => '正在添加…';

  @override
  String get taskRunPending => '正在启动…';

  @override
  String get taskNewProjectTitle => '新建项目';

  @override
  String get taskProjectNameLabel => '项目名称';

  @override
  String get taskCreateProjectAction => '创建';

  @override
  String get taskMineOnlyFilter => '只看指派给我';

  @override
  String get taskAllProjectsFilter => '全部项目';

  @override
  String get taskAllStatusesFilter => '全部';

  @override
  String get taskEmptyState => '还没有任务，在下方添加第一条。';

  @override
  String get taskUnassigned => '未指派';

  @override
  String get taskChangeStatusAction => '变更状态';

  @override
  String get taskStatusOpen => '待处理';

  @override
  String get taskStatusInProgress => '进行中';

  @override
  String get taskStatusBlocked => '受阻';

  @override
  String get taskStatusDone => '已完成';

  @override
  String get taskStatusCancelled => '已取消';

  @override
  String get taskSummaryTotal => '总计';

  @override
  String get taskSummaryOpen => '待处理';

  @override
  String get taskSummaryInProgress => '进行中';

  @override
  String get taskSummaryBlocked => '受阻';

  @override
  String get taskSummaryDone => '已完成';

  @override
  String unreadCountLabel(int count) {
    return '$count 条未读';
  }

  @override
  String get showCollaborationDetails => '展开协作详情';

  @override
  String get hideCollaborationDetails => '收起协作详情';

  @override
  String get roleOwner => '所有者';

  @override
  String get roleMaintainer => '维护者';

  @override
  String get roleOperator => '执行者';

  @override
  String get roleViewer => '观察者';

  @override
  String get workspaceRolePickerLabel => '变更成员角色';

  @override
  String get workspaceRoleManagerTitle => '成员与角色';

  @override
  String get inspectorContext => '上下文';

  @override
  String get inspectorExecution => '执行';

  @override
  String get agentRunsEmpty => '还没有 Agent 运行';

  @override
  String get agentRunsRefresh => '刷新';

  @override
  String get agentRunCancel => '取消运行';

  @override
  String get agentRunRetry => '重试';

  @override
  String get agentRunApprove => '批准';

  @override
  String get agentRunReject => '拒绝';

  @override
  String get agentRunRejectReason => '原因（可选）';

  @override
  String get agentRunApprovalRequired => '需要审批';

  @override
  String get agentRunImpact => '影响';

  @override
  String get agentRunTarget => '目标';

  @override
  String get agentRunRisk => '风险';

  @override
  String get agentRiskReadOnly => '只读';

  @override
  String get agentRiskInternalWrite => '内部修改';

  @override
  String get agentRiskExternalWrite => '外部修改';

  @override
  String get agentRiskDestructive => '破坏性操作';

  @override
  String get agentRiskUnknown => '未知风险';

  @override
  String agentRunStepCount(int count) {
    return '$count 步';
  }

  @override
  String agentRunError(String message) {
    return '错误：$message';
  }

  @override
  String get agentRunStatusQueued => '排队中';

  @override
  String get agentRunStatusContextBuilding => '整理上下文';

  @override
  String get agentRunStatusRunning => '执行中';

  @override
  String get agentRunStatusWaitingApproval => '等待审批';

  @override
  String get agentRunStatusSucceeded => '已完成';

  @override
  String get agentRunStatusFailed => '失败';

  @override
  String get agentRunStatusCancelled => '已取消';

  @override
  String get agentRunSourcesTitle => '上下文来源';

  @override
  String get agentRunArtifactsTitle => '产物';

  @override
  String get agentRunsWaiting => '等待审批';

  @override
  String get destinationConnectors => '连接器';

  @override
  String get toolConnectorsDescription => '按需连接邮件、日历与文件。';

  @override
  String get connectorsTitle => '连接器';

  @override
  String get connectorsSubtitle => '凭据默认私有，共享需要显式开启。';

  @override
  String get connectorAdd => '添加连接器';

  @override
  String get connectorEdit => '编辑连接器';

  @override
  String get connectorName => '名称';

  @override
  String get connectorKind => '类型';

  @override
  String get connectorHost => '主机';

  @override
  String get connectorPort => '端口';

  @override
  String get connectorBaseUrl => '基础地址';

  @override
  String get connectorUsername => '用户名';

  @override
  String get connectorPassword => '密码或应用专用密码';

  @override
  String get connectorPasswordUnchanged => '留空则保留已保存的密码';

  @override
  String get connectorRead => '读取';

  @override
  String get connectorWrite => '写入（需审批）';

  @override
  String get connectorSharing => '共享范围';

  @override
  String get connectorSharingPrivate => '仅自己';

  @override
  String get connectorSharingWorkspace => '整个工作区';

  @override
  String get connectorSharingSelected => '指定成员';

  @override
  String get connectorSharedWith => '共享给';

  @override
  String get connectorTest => '测试连接';

  @override
  String get connectorStatusUnverified => '未测试';

  @override
  String get connectorStatusActive => '已验证';

  @override
  String get connectorStatusFailed => '检查失败';

  @override
  String get connectorDelete => '删除连接器';

  @override
  String connectorDeleteConfirm(String name) {
    return '删除 $name？运行会立即失去访问权限。';
  }

  @override
  String get connectorEmpty => '还没有连接器';

  @override
  String get connectorEmptyHint => '添加后 Agent 可读取邮件或写入文件，写入始终需要你审批。';

  @override
  String get connectorOwnerLabel => '所有者';

  @override
  String get connectorSharedByOther => '他人共享给你';

  @override
  String connectorSaveFailed(String error) {
    return '保存失败：$error';
  }

  @override
  String connectorTestFailed(String error) {
    return '测试失败：$error';
  }

  @override
  String connectorSecretsSet(String fields) {
    return '已保存：$fields';
  }

  @override
  String get connectorNoSecrets => '未保存凭据';

  @override
  String get connectorNoMembers => '没有其他成员';

  @override
  String get save => '保存';

  @override
  String get connectorFieldRequired => '该项必填';

  @override
  String get retryLabel => '重试';

  @override
  String get agentRunEventsTitle => '执行记录';

  @override
  String get taskRunAgentAction => '交给 Agent';

  @override
  String get taskRunQueued => '已为该任务排队一次运行';

  @override
  String get toolAgentRunsDescription => '查看 Agent 正在做什么、哪些操作等待审批。';

  @override
  String get destinationMyWork => '我的工作';

  @override
  String get myWorkSubtitle => '现在需要你处理的，和还在等别人的。';

  @override
  String get myWorkScopeMine => '我的';

  @override
  String get myWorkScopeAll => '全部任务';

  @override
  String get myWorkLaneActionable => '待处理';

  @override
  String get myWorkLaneBlocked => '受阻';

  @override
  String get myWorkLaneAwaitingOthers => '等待他人';

  @override
  String get myWorkLaneRecentlyDone => '最近完成';

  @override
  String get myWorkEmptyTitle => '手上没有待办';

  @override
  String get myWorkEmptyDescription => '分配给你的任务会出现在这里，也可以去全部任务里挑一件。';

  @override
  String get myWorkLaneEmpty => '这一栏是空的。';

  @override
  String get myWorkErrorTitle => '我的工作加载失败';

  @override
  String myWorkDueOn(String date) {
    return '截止 $date';
  }

  @override
  String get myWorkOverdue => '已逾期';

  @override
  String get myWorkRunTooltip => '打开该任务的运行';

  @override
  String get chatCreateTaskTooltip => '转为任务';

  @override
  String get taskFromMessageTitle => '用这条消息新建任务';

  @override
  String get taskFromMessageTitleLabel => '任务标题';

  @override
  String get taskFromMessageCreated => '已加入我的工作';

  @override
  String get myWorkLaneRunning => '运行中';

  @override
  String get myWorkLaneWaitingApproval => '待审批';

  @override
  String get agentRunsOfflineStatus => '实时连接已断开，正在查询活跃运行。';

  @override
  String get agentRunDetailTitle => '运行详情';

  @override
  String get agentRunStepsTitle => '执行步骤';

  @override
  String get agentRunStepsEmpty => '暂无执行步骤';

  @override
  String agentRunModelStep(String agentKey) {
    return 'Agent @$agentKey';
  }

  @override
  String get agentRunStepRejected => '已拒绝';

  @override
  String get agentRunEventApproved => '动作已批准';

  @override
  String get agentRunEventRejected => '动作已拒绝';

  @override
  String get agentRunEventModelStarted => 'Agent 开始处理';

  @override
  String get agentRunEventModelCompleted => 'Agent 完成本轮处理';

  @override
  String get agentRunEventToolStarted => '动作开始执行';

  @override
  String get agentRunEventToolCompleted => '动作执行完成';

  @override
  String get agentRunEventArtifactCreated => '产物已保存';

  @override
  String get agentRunEventUpdated => '运行已更新';

  @override
  String get workspaceManagementTitle => '工作区管理';

  @override
  String get destinationWorkspaceManagement => '管理';

  @override
  String get toolWorkspaceManagementDescription => '查看工作区成员并管理角色。';

  @override
  String get searchConversationsHint => '搜索会话';

  @override
  String get noMatchingConversations => '没有匹配的会话';

  @override
  String get clearSearch => '清除搜索';

  @override
  String get mentionAgent => '提及 Agent';

  @override
  String composerShortcuts(String modifier) {
    return '$modifier+Enter 发送 · Enter 换行';
  }

  @override
  String get workspaceToolsHeading => '工作区工具';

  @override
  String get preferencesHeading => '偏好设置';

  @override
  String get languageChinese => '中文';

  @override
  String get chooseTaskGroup => '选择任务分组';

  @override
  String conversationLoadError(String error) {
    return '无法打开会话，请重试：$error';
  }

  @override
  String get switchingWorkspaceLabel => '正在切换工作区';
}
