// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Weilan';

  @override
  String get language => 'Language';

  @override
  String get theme => 'Theme';

  @override
  String get lightMode => 'Light';

  @override
  String get darkMode => 'Dark';

  @override
  String get english => 'English';

  @override
  String get simplifiedChinese => 'Simplified Chinese';

  @override
  String get searchContacts => 'Search contacts';

  @override
  String get signInTitle => 'Sign in';

  @override
  String get signInDescription => 'Continue to your local workspace.';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get signingIn => 'Signing in...';

  @override
  String get enterWorkspace => 'Enter workspace';

  @override
  String restoreSessionError(Object error) {
    return 'Unable to restore session: $error';
  }

  @override
  String workspaceLoadError(Object error) {
    return 'Unable to load workspace: $error';
  }

  @override
  String get signOutTooltip => 'Sign out';

  @override
  String get workspaceDescription =>
      'Conversations, teammates, and agents in one place.';

  @override
  String get workspace => 'Workspace';

  @override
  String get workspaceHub => 'Workspace hub';

  @override
  String get collaboration => 'Collaboration';

  @override
  String get conversations => 'Conversations';

  @override
  String get channels => 'Channels';

  @override
  String get members => 'Members';

  @override
  String get chatTab => 'Chat';

  @override
  String get pinnedChannels => 'Pinned channels';

  @override
  String get automationChannels => 'Automation';

  @override
  String get teamChannels => 'Team channels';

  @override
  String get contacts => 'Contacts';

  @override
  String get membersGroup => 'Members';

  @override
  String get agentsGroup => 'Agents';

  @override
  String contactsCount(int count) {
    return '$count contacts';
  }

  @override
  String channelTotal(int count) {
    return '$count total';
  }

  @override
  String conversationCountLabel(int count) {
    return '$count conversations';
  }

  @override
  String get unreadLabel => 'Unread';

  @override
  String get directMessages => 'Direct messages';

  @override
  String get agentThreads => 'Agent threads';

  @override
  String get previewLabel => 'Preview';

  @override
  String get memberConversationHint => '1:1 team conversation';

  @override
  String get agentConversationHint => 'Private agent conversation';

  @override
  String get privateConversationPreview => 'This conversation is unavailable.';

  @override
  String get localFirst => 'Local-first';

  @override
  String get sqlite => 'SQLite';

  @override
  String get virtualThreads => 'Virtual Threads';

  @override
  String get online => 'Online';

  @override
  String activeCountLabel(int count) {
    return '$count active';
  }

  @override
  String messageCountLabel(int count) {
    return '$count messages';
  }

  @override
  String get recentActivityLabel => 'Recent activity';

  @override
  String get recentInteractions => 'Recent interactions';

  @override
  String get noRecentInteractions =>
      'No recent interactions yet. Team messages and agent replies will appear here.';

  @override
  String get aiCoworker => 'AI coworker';

  @override
  String get connected => 'Connected';

  @override
  String get connecting => 'Connecting';

  @override
  String get disconnected => 'Disconnected';

  @override
  String get realtimeError => 'Realtime error';

  @override
  String get idle => 'Idle';

  @override
  String get aiEnabled => 'AI enabled';

  @override
  String get chatPanelDescription => 'Team conversation';

  @override
  String get noMessagesTitle => 'No messages yet';

  @override
  String get noMessagesDescription => 'Send the first message.';

  @override
  String get quickActionsLabel => 'Quick actions';

  @override
  String get pressEnterToSend => 'Press Enter to send';

  @override
  String get sendingMessage => 'Sending message...';

  @override
  String get typeMessageHint =>
      'Type a message for the team, or use @assistant when needed';

  @override
  String membersCountLabel(int count) {
    return '$count members';
  }

  @override
  String get send => 'Send';

  @override
  String get sending => 'Sending';

  @override
  String messageSendFailed(Object error) {
    return 'Message send failed: $error';
  }

  @override
  String get agents => 'Agents';

  @override
  String get availableAgents => 'Available agents';

  @override
  String enabledCount(int count) {
    return '$count enabled';
  }

  @override
  String queueCountLabel(int count) {
    return '$count queued';
  }

  @override
  String get enabled => 'Enabled';

  @override
  String get disabled => 'Disabled';

  @override
  String get runActivity => 'Run Activity';

  @override
  String get noAgentExecutions =>
      'No agent executions yet. Mention an agent in chat to start a run.';

  @override
  String get queued => 'Queued';

  @override
  String get running => 'Running';

  @override
  String get completed => 'Completed';

  @override
  String get failed => 'Failed';

  @override
  String executionLabel(Object id) {
    return 'Execution $id';
  }

  @override
  String get aiBadge => 'AI';

  @override
  String memberLabel(Object id) {
    return 'Member $id';
  }

  @override
  String get memberYouLabel => 'You';

  @override
  String get todayLabel => 'Today';

  @override
  String get yesterdayLabel => 'Yesterday';

  @override
  String get agentRunsTitle => 'Agent runs';

  @override
  String get recentExecutions => 'Recent executions';

  @override
  String get collaborationMode => 'Team mode';

  @override
  String get collaborationModeHint =>
      'Auto-route new channel messages through @team.';

  @override
  String collaborationRoundStatus(int round, int total) {
    return 'round $round of $total';
  }

  @override
  String collaborationRunningStatus(Object agentLabel, Object roundLabel) {
    return '$agentLabel is coordinating $roundLabel.';
  }

  @override
  String collaborationCompletedStatus(Object trigger, int totalRounds) {
    return 'Team run finished via $trigger in $totalRounds rounds.';
  }

  @override
  String get collaborationStoppedStatus => 'Team run stopped.';

  @override
  String get summarizeArchitectureChanges => 'Summarize architecture changes';

  @override
  String get nativeImagePreflightChecks => 'Native image preflight checks';

  @override
  String get cancel => 'Cancel';

  @override
  String get create => 'Create';

  @override
  String get add => 'Add';

  @override
  String get newWorkspaceTitle => 'New workspace';

  @override
  String get workspaceNameLabel => 'Workspace name';

  @override
  String get workspaceNameHint => 'Platform Ops';

  @override
  String get addWorkspaceMemberTitle => 'Add workspace member';

  @override
  String get userEmailLabel => 'User email';

  @override
  String get userEmailHint => 'teammate@microflow.local';

  @override
  String get switchWorkspaceTooltip => 'Switch workspace';

  @override
  String get knowledgeTooltip => 'Knowledge';

  @override
  String get addMemberTooltip => 'Add member';

  @override
  String get agentDiagnosticsTooltip => 'Agent diagnostics';

  @override
  String get ownerRole => 'Owner';

  @override
  String get knowledgeBaseTitle => 'Knowledge base';

  @override
  String get refreshTooltip => 'Refresh';

  @override
  String get uploadFileTooltip => 'Upload file';

  @override
  String get uploadTargetLabel => 'Upload target';

  @override
  String get workspaceLibrary => 'Workspace library';

  @override
  String uploadTargetConversationDescription(Object conversation) {
    return 'New files will be attached to $conversation and prioritized there during retrieval.';
  }

  @override
  String get uploadTargetWorkspaceDescription =>
      'New files will be available as workspace-wide knowledge across conversations.';

  @override
  String get allDocuments => 'All documents';

  @override
  String get workspaceWide => 'Workspace-wide';

  @override
  String get searchDocumentsHint => 'Search documents';

  @override
  String get referencedSourceNotice =>
      'Referenced source highlighted from chat citation.';

  @override
  String get knowledgeEmptyDescription => 'Upload a document to begin.';

  @override
  String get knowledgeEmptySearchDescription =>
      'No knowledge documents match the current search.';

  @override
  String snippetsCount(int count) {
    return '$count snippets';
  }

  @override
  String get referencedSource => 'Referenced source';

  @override
  String get teamRunsAvailable =>
      'Persisted team runs are available for this conversation.';

  @override
  String get history => 'History';

  @override
  String get recentRuns => 'Recent runs';

  @override
  String get runHistory => 'Run history';

  @override
  String get noRunsMatchFilters => 'No runs match current filters.';

  @override
  String get filterRuns => 'Filter runs';

  @override
  String get allRuns => 'All runs';

  @override
  String get currentRun => 'Current run';

  @override
  String get filterByStatus => 'Filter by status';

  @override
  String get allStatuses => 'All statuses';

  @override
  String get stopped => 'Stopped';

  @override
  String get filterByAgent => 'Filter by agent';

  @override
  String get allAgents => 'All agents';

  @override
  String get live => 'Live';

  @override
  String eventsCount(int count) {
    return '$count events';
  }

  @override
  String roundsCount(int round, int total) {
    return '$round of $total rounds';
  }

  @override
  String reasonLabel(Object reason) {
    return 'Reason: $reason';
  }

  @override
  String get analyzeStage => 'Analyze';

  @override
  String get critiqueStage => 'Critique';

  @override
  String get synthesizeStage => 'Synthesize';

  @override
  String get deliverStage => 'Deliver';

  @override
  String collaborationStageInProgress(Object stage) {
    return '$stage in progress';
  }

  @override
  String collaborationStageCompleted(Object stage) {
    return '$stage completed';
  }

  @override
  String collaborationStageStopped(Object stage) {
    return '$stage stopped';
  }

  @override
  String collaborationStageFailed(Object stage) {
    return '$stage failed';
  }

  @override
  String collaborationStageStatus(Object stage, Object status) {
    return '$stage $status';
  }

  @override
  String get workspaceScopeLabel => 'Workspace';

  @override
  String get scopedScopeLabel => 'Scoped';

  @override
  String get indexTab => 'Index';

  @override
  String get toolsTab => 'Tools';

  @override
  String get toolsTitle => 'Tools';

  @override
  String get toolKnowledgeDescription => 'Open documents for this workspace.';

  @override
  String get toolAccountingDescription =>
      'Review accounts, vouchers, and the trial balance.';

  @override
  String get toolDiagnosticsDescription =>
      'Check agent health and role strategy.';

  @override
  String get toolAppearanceDescription => 'Switch between light and dark.';

  @override
  String get toolLanguageDescription => 'Use Chinese or English.';

  @override
  String get toolSignOutDescription => 'Leave this workspace on this device.';

  @override
  String get inspectorCurrent => 'Current';

  @override
  String get inspectorCollaboration => 'Collaboration';

  @override
  String get inspectorKnowledge => 'Documents';

  @override
  String get backToConversation => 'Back to conversation';

  @override
  String get signOutConfirmTitle => 'Sign out?';

  @override
  String get signOutConfirmBody =>
      'You will leave this workspace on this device.';

  @override
  String get openInspectorTooltip => 'Details';

  @override
  String get openToolsTooltip => 'Tools';

  @override
  String get destinationConversation => 'Chat';

  @override
  String get destinationKnowledge => 'Knowledge';

  @override
  String get destinationAccounting => 'Accounting';

  @override
  String get destinationDiagnostics => 'Diagnostics';

  @override
  String get destinationTasks => 'Tasks';

  @override
  String get taskNewTaskHint => 'What needs to move forward?';

  @override
  String get taskCreateAction => 'Add';

  @override
  String get taskCreatePending => 'Adding…';

  @override
  String get taskRunPending => 'Starting…';

  @override
  String get taskNewProjectTitle => 'New project';

  @override
  String get taskProjectNameLabel => 'Project name';

  @override
  String get taskCreateProjectAction => 'Create';

  @override
  String get taskMineOnlyFilter => 'Assigned to me';

  @override
  String get taskAllProjectsFilter => 'All projects';

  @override
  String get taskAllStatusesFilter => 'All';

  @override
  String get taskEmptyState => 'No tasks yet. Add the first one below.';

  @override
  String get taskUnassigned => 'Unassigned';

  @override
  String get taskChangeStatusAction => 'Change status';

  @override
  String get taskStatusOpen => 'Open';

  @override
  String get taskStatusInProgress => 'In progress';

  @override
  String get taskStatusBlocked => 'Blocked';

  @override
  String get taskStatusDone => 'Done';

  @override
  String get taskStatusCancelled => 'Cancelled';

  @override
  String get taskSummaryTotal => 'Total';

  @override
  String get taskSummaryOpen => 'Open';

  @override
  String get taskSummaryInProgress => 'Doing';

  @override
  String get taskSummaryBlocked => 'Blocked';

  @override
  String get taskSummaryDone => 'Done';

  @override
  String unreadCountLabel(int count) {
    return '$count unread';
  }

  @override
  String get showCollaborationDetails => 'Show collaboration details';

  @override
  String get hideCollaborationDetails => 'Hide collaboration details';

  @override
  String get roleOwner => 'Owner';

  @override
  String get roleMaintainer => 'Maintainer';

  @override
  String get roleOperator => 'Operator';

  @override
  String get roleViewer => 'Viewer';

  @override
  String get workspaceRolePickerLabel => 'Change member role';

  @override
  String get workspaceRoleManagerTitle => 'Members and roles';

  @override
  String get inspectorContext => 'Context';

  @override
  String get inspectorExecution => 'Execution';

  @override
  String get agentRunsEmpty => 'No agent runs yet';

  @override
  String get agentRunsRefresh => 'Refresh';

  @override
  String get agentRunCancel => 'Cancel run';

  @override
  String get agentRunRetry => 'Retry';

  @override
  String get agentRunApprove => 'Approve';

  @override
  String get agentRunReject => 'Reject';

  @override
  String get agentRunRejectReason => 'Reason (optional)';

  @override
  String get agentRunApprovalRequired => 'Approval required';

  @override
  String get agentRunImpact => 'Impact';

  @override
  String get agentRunTarget => 'Target';

  @override
  String get agentRunRisk => 'Risk';

  @override
  String get agentRiskReadOnly => 'Read only';

  @override
  String get agentRiskInternalWrite => 'Internal change';

  @override
  String get agentRiskExternalWrite => 'External change';

  @override
  String get agentRiskDestructive => 'Destructive';

  @override
  String get agentRiskUnknown => 'Unknown risk';

  @override
  String agentRunStepCount(int count) {
    return '$count steps';
  }

  @override
  String agentRunError(String message) {
    return 'Error: $message';
  }

  @override
  String get agentRunStatusQueued => 'Queued';

  @override
  String get agentRunStatusContextBuilding => 'Gathering context';

  @override
  String get agentRunStatusRunning => 'Running';

  @override
  String get agentRunStatusWaitingApproval => 'Waiting approval';

  @override
  String get agentRunStatusSucceeded => 'Completed';

  @override
  String get agentRunStatusFailed => 'Failed';

  @override
  String get agentRunStatusCancelled => 'Cancelled';

  @override
  String get agentRunSourcesTitle => 'Context sources';

  @override
  String get agentRunArtifactsTitle => 'Artifacts';

  @override
  String get agentRunsWaiting => 'Waiting for approval';

  @override
  String get destinationConnectors => 'Connectors';

  @override
  String get toolConnectorsDescription =>
      'Connect mail, calendars and files on demand.';

  @override
  String get connectorsTitle => 'Connectors';

  @override
  String get connectorsSubtitle =>
      'Credentials stay private until you share them.';

  @override
  String get connectorAdd => 'Add connector';

  @override
  String get connectorEdit => 'Edit connector';

  @override
  String get connectorName => 'Name';

  @override
  String get connectorKind => 'Type';

  @override
  String get connectorHost => 'Host';

  @override
  String get connectorPort => 'Port';

  @override
  String get connectorBaseUrl => 'Base URL';

  @override
  String get connectorUsername => 'Username';

  @override
  String get connectorPassword => 'Password or app password';

  @override
  String get connectorPasswordUnchanged =>
      'Leave blank to keep the stored password';

  @override
  String get connectorRead => 'Read';

  @override
  String get connectorWrite => 'Write (needs approval)';

  @override
  String get connectorSharing => 'Sharing';

  @override
  String get connectorSharingPrivate => 'Only me';

  @override
  String get connectorSharingWorkspace => 'Whole workspace';

  @override
  String get connectorSharingSelected => 'Selected people';

  @override
  String get connectorSharedWith => 'Shared with';

  @override
  String get connectorTest => 'Test connection';

  @override
  String get connectorStatusUnverified => 'Not tested';

  @override
  String get connectorStatusActive => 'Verified';

  @override
  String get connectorStatusFailed => 'Check failed';

  @override
  String get connectorDelete => 'Delete connector';

  @override
  String connectorDeleteConfirm(String name) {
    return 'Delete $name? Runs will lose access immediately.';
  }

  @override
  String get connectorEmpty => 'No connectors yet';

  @override
  String get connectorEmptyHint =>
      'Add one so an agent can read mail or write files — writes always need your approval.';

  @override
  String get connectorOwnerLabel => 'Owner';

  @override
  String get connectorSharedByOther => 'Shared with you';

  @override
  String connectorSaveFailed(String error) {
    return 'Could not save: $error';
  }

  @override
  String connectorTestFailed(String error) {
    return 'Could not test: $error';
  }

  @override
  String connectorSecretsSet(String fields) {
    return 'Stored: $fields';
  }

  @override
  String get connectorNoSecrets => 'No credentials stored';

  @override
  String get connectorNoMembers => 'No other members';

  @override
  String get save => 'Save';

  @override
  String get connectorFieldRequired => 'This field is required';

  @override
  String get retryLabel => 'Retry';

  @override
  String get agentRunEventsTitle => 'Execution trail';

  @override
  String get taskRunAgentAction => 'Run agent';

  @override
  String get taskRunQueued => 'Run queued for this task';

  @override
  String get toolAgentRunsDescription =>
      'See what the agents are doing and what needs approval.';

  @override
  String get destinationMyWork => 'My work';

  @override
  String get myWorkSubtitle =>
      'What needs you now, and what is waiting on someone else.';

  @override
  String get myWorkScopeMine => 'For me';

  @override
  String get myWorkScopeAll => 'All tasks';

  @override
  String get myWorkLaneActionable => 'To do';

  @override
  String get myWorkLaneBlocked => 'Blocked';

  @override
  String get myWorkLaneAwaitingOthers => 'Waiting on others';

  @override
  String get myWorkLaneRecentlyDone => 'Recently done';

  @override
  String get myWorkEmptyTitle => 'Nothing is waiting on you';

  @override
  String get myWorkEmptyDescription =>
      'Assignments land here. Browse all tasks to pick something up.';

  @override
  String get myWorkLaneEmpty => 'Nothing in this lane.';

  @override
  String get myWorkErrorTitle => 'My work could not load';

  @override
  String myWorkDueOn(String date) {
    return 'Due $date';
  }

  @override
  String get myWorkOverdue => 'Overdue';

  @override
  String get myWorkRunTooltip => 'Open the agent run for this task';

  @override
  String get chatCreateTaskTooltip => 'Turn into a task';

  @override
  String get taskFromMessageTitle => 'New task from this message';

  @override
  String get taskFromMessageTitleLabel => 'Task title';

  @override
  String get taskFromMessageCreated => 'Added to my work';

  @override
  String get myWorkLaneRunning => 'Running';

  @override
  String get myWorkLaneWaitingApproval => 'To review';

  @override
  String get agentRunsOfflineStatus =>
      'Live updates disconnected. Checking active runs.';

  @override
  String get agentRunDetailTitle => 'Run details';

  @override
  String get agentRunStepsTitle => 'Steps';

  @override
  String get agentRunStepsEmpty => 'No steps yet';

  @override
  String agentRunModelStep(String agentKey) {
    return 'Agent @$agentKey';
  }

  @override
  String get agentRunStepRejected => 'Rejected';

  @override
  String get agentRunEventApproved => 'Action approved';

  @override
  String get agentRunEventRejected => 'Action rejected';

  @override
  String get agentRunEventModelStarted => 'Agent started a turn';

  @override
  String get agentRunEventModelCompleted => 'Agent completed a turn';

  @override
  String get agentRunEventToolStarted => 'Action started';

  @override
  String get agentRunEventToolCompleted => 'Action completed';

  @override
  String get agentRunEventArtifactCreated => 'Artifact saved';

  @override
  String get agentRunEventUpdated => 'Run updated';

  @override
  String get workspaceManagementTitle => 'Workspace management';

  @override
  String get destinationWorkspaceManagement => 'Manage';

  @override
  String get toolWorkspaceManagementDescription =>
      'Review members and manage their roles.';

  @override
  String get searchConversationsHint => 'Search conversations';

  @override
  String get noMatchingConversations => 'No matching conversations';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get mentionAgent => 'Mention an agent';

  @override
  String composerShortcuts(String modifier) {
    return '$modifier+Enter to send · Enter for a new line';
  }

  @override
  String get workspaceToolsHeading => 'Workspace tools';

  @override
  String get preferencesHeading => 'Preferences';

  @override
  String get languageChinese => '中文';

  @override
  String get chooseTaskGroup => 'Choose task group';

  @override
  String conversationLoadError(String error) {
    return 'Couldn\'t open the conversation. Try again: $error';
  }

  @override
  String get switchingWorkspaceLabel => 'Switching workspace';
}
