import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Weilan'**
  String get appTitle;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @lightMode.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get lightMode;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get darkMode;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @simplifiedChinese.
  ///
  /// In en, this message translates to:
  /// **'Simplified Chinese'**
  String get simplifiedChinese;

  /// No description provided for @searchContacts.
  ///
  /// In en, this message translates to:
  /// **'Search contacts'**
  String get searchContacts;

  /// No description provided for @signInTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signInTitle;

  /// No description provided for @signInDescription.
  ///
  /// In en, this message translates to:
  /// **'Continue to your local workspace.'**
  String get signInDescription;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @signingIn.
  ///
  /// In en, this message translates to:
  /// **'Signing in...'**
  String get signingIn;

  /// No description provided for @enterWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Enter workspace'**
  String get enterWorkspace;

  /// No description provided for @restoreSessionError.
  ///
  /// In en, this message translates to:
  /// **'Unable to restore session: {error}'**
  String restoreSessionError(Object error);

  /// No description provided for @workspaceLoadError.
  ///
  /// In en, this message translates to:
  /// **'Unable to load workspace: {error}'**
  String workspaceLoadError(Object error);

  /// No description provided for @signOutTooltip.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOutTooltip;

  /// No description provided for @workspaceDescription.
  ///
  /// In en, this message translates to:
  /// **'Conversations, teammates, and agents in one place.'**
  String get workspaceDescription;

  /// No description provided for @workspace.
  ///
  /// In en, this message translates to:
  /// **'Workspace'**
  String get workspace;

  /// No description provided for @workspaceHub.
  ///
  /// In en, this message translates to:
  /// **'Workspace hub'**
  String get workspaceHub;

  /// No description provided for @collaboration.
  ///
  /// In en, this message translates to:
  /// **'Collaboration'**
  String get collaboration;

  /// No description provided for @conversations.
  ///
  /// In en, this message translates to:
  /// **'Conversations'**
  String get conversations;

  /// No description provided for @channels.
  ///
  /// In en, this message translates to:
  /// **'Channels'**
  String get channels;

  /// No description provided for @members.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get members;

  /// No description provided for @chatTab.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chatTab;

  /// No description provided for @pinnedChannels.
  ///
  /// In en, this message translates to:
  /// **'Pinned channels'**
  String get pinnedChannels;

  /// No description provided for @automationChannels.
  ///
  /// In en, this message translates to:
  /// **'Automation'**
  String get automationChannels;

  /// No description provided for @teamChannels.
  ///
  /// In en, this message translates to:
  /// **'Team channels'**
  String get teamChannels;

  /// No description provided for @contacts.
  ///
  /// In en, this message translates to:
  /// **'Contacts'**
  String get contacts;

  /// No description provided for @membersGroup.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get membersGroup;

  /// No description provided for @agentsGroup.
  ///
  /// In en, this message translates to:
  /// **'Agents'**
  String get agentsGroup;

  /// No description provided for @contactsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} contacts'**
  String contactsCount(int count);

  /// No description provided for @channelTotal.
  ///
  /// In en, this message translates to:
  /// **'{count} total'**
  String channelTotal(int count);

  /// No description provided for @conversationCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} conversations'**
  String conversationCountLabel(int count);

  /// No description provided for @unreadLabel.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get unreadLabel;

  /// No description provided for @directMessages.
  ///
  /// In en, this message translates to:
  /// **'Direct messages'**
  String get directMessages;

  /// No description provided for @agentThreads.
  ///
  /// In en, this message translates to:
  /// **'Agent threads'**
  String get agentThreads;

  /// No description provided for @previewLabel.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get previewLabel;

  /// No description provided for @memberConversationHint.
  ///
  /// In en, this message translates to:
  /// **'1:1 team conversation'**
  String get memberConversationHint;

  /// No description provided for @agentConversationHint.
  ///
  /// In en, this message translates to:
  /// **'Private agent conversation'**
  String get agentConversationHint;

  /// No description provided for @privateConversationPreview.
  ///
  /// In en, this message translates to:
  /// **'This conversation is unavailable.'**
  String get privateConversationPreview;

  /// No description provided for @localFirst.
  ///
  /// In en, this message translates to:
  /// **'Local-first'**
  String get localFirst;

  /// No description provided for @sqlite.
  ///
  /// In en, this message translates to:
  /// **'SQLite'**
  String get sqlite;

  /// No description provided for @virtualThreads.
  ///
  /// In en, this message translates to:
  /// **'Virtual Threads'**
  String get virtualThreads;

  /// No description provided for @online.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get online;

  /// No description provided for @activeCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} active'**
  String activeCountLabel(int count);

  /// No description provided for @messageCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} messages'**
  String messageCountLabel(int count);

  /// No description provided for @recentActivityLabel.
  ///
  /// In en, this message translates to:
  /// **'Recent activity'**
  String get recentActivityLabel;

  /// No description provided for @recentInteractions.
  ///
  /// In en, this message translates to:
  /// **'Recent interactions'**
  String get recentInteractions;

  /// No description provided for @noRecentInteractions.
  ///
  /// In en, this message translates to:
  /// **'No recent interactions yet. Team messages and agent replies will appear here.'**
  String get noRecentInteractions;

  /// No description provided for @aiCoworker.
  ///
  /// In en, this message translates to:
  /// **'AI coworker'**
  String get aiCoworker;

  /// No description provided for @connected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connected;

  /// No description provided for @connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting'**
  String get connecting;

  /// No description provided for @disconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get disconnected;

  /// No description provided for @realtimeError.
  ///
  /// In en, this message translates to:
  /// **'Realtime error'**
  String get realtimeError;

  /// No description provided for @idle.
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get idle;

  /// No description provided for @aiEnabled.
  ///
  /// In en, this message translates to:
  /// **'AI enabled'**
  String get aiEnabled;

  /// No description provided for @chatPanelDescription.
  ///
  /// In en, this message translates to:
  /// **'Team conversation'**
  String get chatPanelDescription;

  /// No description provided for @noMessagesTitle.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get noMessagesTitle;

  /// No description provided for @noMessagesDescription.
  ///
  /// In en, this message translates to:
  /// **'Send the first message.'**
  String get noMessagesDescription;

  /// No description provided for @quickActionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Quick actions'**
  String get quickActionsLabel;

  /// No description provided for @pressEnterToSend.
  ///
  /// In en, this message translates to:
  /// **'Press Enter to send'**
  String get pressEnterToSend;

  /// No description provided for @sendingMessage.
  ///
  /// In en, this message translates to:
  /// **'Sending message...'**
  String get sendingMessage;

  /// No description provided for @typeMessageHint.
  ///
  /// In en, this message translates to:
  /// **'Type a message for the team, or use @assistant when needed'**
  String get typeMessageHint;

  /// No description provided for @membersCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} members'**
  String membersCountLabel(int count);

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @sending.
  ///
  /// In en, this message translates to:
  /// **'Sending'**
  String get sending;

  /// No description provided for @messageSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Message send failed: {error}'**
  String messageSendFailed(Object error);

  /// No description provided for @agents.
  ///
  /// In en, this message translates to:
  /// **'Agents'**
  String get agents;

  /// No description provided for @availableAgents.
  ///
  /// In en, this message translates to:
  /// **'Available agents'**
  String get availableAgents;

  /// No description provided for @enabledCount.
  ///
  /// In en, this message translates to:
  /// **'{count} enabled'**
  String enabledCount(int count);

  /// No description provided for @queueCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} queued'**
  String queueCountLabel(int count);

  /// No description provided for @enabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get enabled;

  /// No description provided for @disabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get disabled;

  /// No description provided for @runActivity.
  ///
  /// In en, this message translates to:
  /// **'Run Activity'**
  String get runActivity;

  /// No description provided for @noAgentExecutions.
  ///
  /// In en, this message translates to:
  /// **'No agent executions yet. Mention an agent in chat to start a run.'**
  String get noAgentExecutions;

  /// No description provided for @queued.
  ///
  /// In en, this message translates to:
  /// **'Queued'**
  String get queued;

  /// No description provided for @running.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get running;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @failed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get failed;

  /// No description provided for @executionLabel.
  ///
  /// In en, this message translates to:
  /// **'Execution {id}'**
  String executionLabel(Object id);

  /// No description provided for @aiBadge.
  ///
  /// In en, this message translates to:
  /// **'AI'**
  String get aiBadge;

  /// No description provided for @memberLabel.
  ///
  /// In en, this message translates to:
  /// **'Member {id}'**
  String memberLabel(Object id);

  /// No description provided for @memberYouLabel.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get memberYouLabel;

  /// No description provided for @todayLabel.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get todayLabel;

  /// No description provided for @yesterdayLabel.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterdayLabel;

  /// No description provided for @agentRunsTitle.
  ///
  /// In en, this message translates to:
  /// **'Agent runs'**
  String get agentRunsTitle;

  /// No description provided for @recentExecutions.
  ///
  /// In en, this message translates to:
  /// **'Recent executions'**
  String get recentExecutions;

  /// No description provided for @collaborationMode.
  ///
  /// In en, this message translates to:
  /// **'Team mode'**
  String get collaborationMode;

  /// No description provided for @collaborationModeHint.
  ///
  /// In en, this message translates to:
  /// **'Auto-route new channel messages through @team.'**
  String get collaborationModeHint;

  /// No description provided for @collaborationRoundStatus.
  ///
  /// In en, this message translates to:
  /// **'round {round} of {total}'**
  String collaborationRoundStatus(int round, int total);

  /// No description provided for @collaborationRunningStatus.
  ///
  /// In en, this message translates to:
  /// **'{agentLabel} is coordinating {roundLabel}.'**
  String collaborationRunningStatus(Object agentLabel, Object roundLabel);

  /// No description provided for @collaborationCompletedStatus.
  ///
  /// In en, this message translates to:
  /// **'Team run finished via {trigger} in {totalRounds} rounds.'**
  String collaborationCompletedStatus(Object trigger, int totalRounds);

  /// No description provided for @collaborationStoppedStatus.
  ///
  /// In en, this message translates to:
  /// **'Team run stopped.'**
  String get collaborationStoppedStatus;

  /// No description provided for @summarizeArchitectureChanges.
  ///
  /// In en, this message translates to:
  /// **'Summarize architecture changes'**
  String get summarizeArchitectureChanges;

  /// No description provided for @nativeImagePreflightChecks.
  ///
  /// In en, this message translates to:
  /// **'Native image preflight checks'**
  String get nativeImagePreflightChecks;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @newWorkspaceTitle.
  ///
  /// In en, this message translates to:
  /// **'New workspace'**
  String get newWorkspaceTitle;

  /// No description provided for @workspaceNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Workspace name'**
  String get workspaceNameLabel;

  /// No description provided for @workspaceNameHint.
  ///
  /// In en, this message translates to:
  /// **'Platform Ops'**
  String get workspaceNameHint;

  /// No description provided for @addWorkspaceMemberTitle.
  ///
  /// In en, this message translates to:
  /// **'Add workspace member'**
  String get addWorkspaceMemberTitle;

  /// No description provided for @userEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'User email'**
  String get userEmailLabel;

  /// No description provided for @userEmailHint.
  ///
  /// In en, this message translates to:
  /// **'teammate@microflow.local'**
  String get userEmailHint;

  /// No description provided for @switchWorkspaceTooltip.
  ///
  /// In en, this message translates to:
  /// **'Switch workspace'**
  String get switchWorkspaceTooltip;

  /// No description provided for @knowledgeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Knowledge'**
  String get knowledgeTooltip;

  /// No description provided for @addMemberTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add member'**
  String get addMemberTooltip;

  /// No description provided for @agentDiagnosticsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Agent diagnostics'**
  String get agentDiagnosticsTooltip;

  /// No description provided for @ownerRole.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get ownerRole;

  /// No description provided for @knowledgeBaseTitle.
  ///
  /// In en, this message translates to:
  /// **'Knowledge base'**
  String get knowledgeBaseTitle;

  /// No description provided for @refreshTooltip.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refreshTooltip;

  /// No description provided for @uploadFileTooltip.
  ///
  /// In en, this message translates to:
  /// **'Upload file'**
  String get uploadFileTooltip;

  /// No description provided for @uploadTargetLabel.
  ///
  /// In en, this message translates to:
  /// **'Upload target'**
  String get uploadTargetLabel;

  /// No description provided for @workspaceLibrary.
  ///
  /// In en, this message translates to:
  /// **'Workspace library'**
  String get workspaceLibrary;

  /// No description provided for @uploadTargetConversationDescription.
  ///
  /// In en, this message translates to:
  /// **'New files will be attached to {conversation} and prioritized there during retrieval.'**
  String uploadTargetConversationDescription(Object conversation);

  /// No description provided for @uploadTargetWorkspaceDescription.
  ///
  /// In en, this message translates to:
  /// **'New files will be available as workspace-wide knowledge across conversations.'**
  String get uploadTargetWorkspaceDescription;

  /// No description provided for @allDocuments.
  ///
  /// In en, this message translates to:
  /// **'All documents'**
  String get allDocuments;

  /// No description provided for @workspaceWide.
  ///
  /// In en, this message translates to:
  /// **'Workspace-wide'**
  String get workspaceWide;

  /// No description provided for @searchDocumentsHint.
  ///
  /// In en, this message translates to:
  /// **'Search documents'**
  String get searchDocumentsHint;

  /// No description provided for @referencedSourceNotice.
  ///
  /// In en, this message translates to:
  /// **'Referenced source highlighted from chat citation.'**
  String get referencedSourceNotice;

  /// No description provided for @knowledgeEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Upload a document to begin.'**
  String get knowledgeEmptyDescription;

  /// No description provided for @knowledgeEmptySearchDescription.
  ///
  /// In en, this message translates to:
  /// **'No knowledge documents match the current search.'**
  String get knowledgeEmptySearchDescription;

  /// No description provided for @snippetsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} snippets'**
  String snippetsCount(int count);

  /// No description provided for @referencedSource.
  ///
  /// In en, this message translates to:
  /// **'Referenced source'**
  String get referencedSource;

  /// No description provided for @teamRunsAvailable.
  ///
  /// In en, this message translates to:
  /// **'Persisted team runs are available for this conversation.'**
  String get teamRunsAvailable;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @recentRuns.
  ///
  /// In en, this message translates to:
  /// **'Recent runs'**
  String get recentRuns;

  /// No description provided for @runHistory.
  ///
  /// In en, this message translates to:
  /// **'Run history'**
  String get runHistory;

  /// No description provided for @noRunsMatchFilters.
  ///
  /// In en, this message translates to:
  /// **'No runs match current filters.'**
  String get noRunsMatchFilters;

  /// No description provided for @filterRuns.
  ///
  /// In en, this message translates to:
  /// **'Filter runs'**
  String get filterRuns;

  /// No description provided for @allRuns.
  ///
  /// In en, this message translates to:
  /// **'All runs'**
  String get allRuns;

  /// No description provided for @currentRun.
  ///
  /// In en, this message translates to:
  /// **'Current run'**
  String get currentRun;

  /// No description provided for @filterByStatus.
  ///
  /// In en, this message translates to:
  /// **'Filter by status'**
  String get filterByStatus;

  /// No description provided for @allStatuses.
  ///
  /// In en, this message translates to:
  /// **'All statuses'**
  String get allStatuses;

  /// No description provided for @stopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get stopped;

  /// No description provided for @filterByAgent.
  ///
  /// In en, this message translates to:
  /// **'Filter by agent'**
  String get filterByAgent;

  /// No description provided for @allAgents.
  ///
  /// In en, this message translates to:
  /// **'All agents'**
  String get allAgents;

  /// No description provided for @live.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get live;

  /// No description provided for @eventsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} events'**
  String eventsCount(int count);

  /// No description provided for @roundsCount.
  ///
  /// In en, this message translates to:
  /// **'{round} of {total} rounds'**
  String roundsCount(int round, int total);

  /// No description provided for @reasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason: {reason}'**
  String reasonLabel(Object reason);

  /// No description provided for @analyzeStage.
  ///
  /// In en, this message translates to:
  /// **'Analyze'**
  String get analyzeStage;

  /// No description provided for @critiqueStage.
  ///
  /// In en, this message translates to:
  /// **'Critique'**
  String get critiqueStage;

  /// No description provided for @synthesizeStage.
  ///
  /// In en, this message translates to:
  /// **'Synthesize'**
  String get synthesizeStage;

  /// No description provided for @deliverStage.
  ///
  /// In en, this message translates to:
  /// **'Deliver'**
  String get deliverStage;

  /// No description provided for @collaborationStageInProgress.
  ///
  /// In en, this message translates to:
  /// **'{stage} in progress'**
  String collaborationStageInProgress(Object stage);

  /// No description provided for @collaborationStageCompleted.
  ///
  /// In en, this message translates to:
  /// **'{stage} completed'**
  String collaborationStageCompleted(Object stage);

  /// No description provided for @collaborationStageStopped.
  ///
  /// In en, this message translates to:
  /// **'{stage} stopped'**
  String collaborationStageStopped(Object stage);

  /// No description provided for @collaborationStageFailed.
  ///
  /// In en, this message translates to:
  /// **'{stage} failed'**
  String collaborationStageFailed(Object stage);

  /// No description provided for @collaborationStageStatus.
  ///
  /// In en, this message translates to:
  /// **'{stage} {status}'**
  String collaborationStageStatus(Object stage, Object status);

  /// No description provided for @workspaceScopeLabel.
  ///
  /// In en, this message translates to:
  /// **'Workspace'**
  String get workspaceScopeLabel;

  /// No description provided for @scopedScopeLabel.
  ///
  /// In en, this message translates to:
  /// **'Scoped'**
  String get scopedScopeLabel;

  /// No description provided for @indexTab.
  ///
  /// In en, this message translates to:
  /// **'Index'**
  String get indexTab;

  /// No description provided for @toolsTab.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get toolsTab;

  /// No description provided for @toolsTitle.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get toolsTitle;

  /// No description provided for @toolKnowledgeDescription.
  ///
  /// In en, this message translates to:
  /// **'Open documents for this workspace.'**
  String get toolKnowledgeDescription;

  /// No description provided for @toolAccountingDescription.
  ///
  /// In en, this message translates to:
  /// **'Review accounts, vouchers, and the trial balance.'**
  String get toolAccountingDescription;

  /// No description provided for @toolDiagnosticsDescription.
  ///
  /// In en, this message translates to:
  /// **'Check agent health and role strategy.'**
  String get toolDiagnosticsDescription;

  /// No description provided for @toolAppearanceDescription.
  ///
  /// In en, this message translates to:
  /// **'Switch between light and dark.'**
  String get toolAppearanceDescription;

  /// No description provided for @toolLanguageDescription.
  ///
  /// In en, this message translates to:
  /// **'Use Chinese or English.'**
  String get toolLanguageDescription;

  /// No description provided for @toolSignOutDescription.
  ///
  /// In en, this message translates to:
  /// **'Leave this workspace on this device.'**
  String get toolSignOutDescription;

  /// No description provided for @inspectorCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get inspectorCurrent;

  /// No description provided for @inspectorCollaboration.
  ///
  /// In en, this message translates to:
  /// **'Collaboration'**
  String get inspectorCollaboration;

  /// No description provided for @inspectorKnowledge.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get inspectorKnowledge;

  /// No description provided for @backToConversation.
  ///
  /// In en, this message translates to:
  /// **'Back to conversation'**
  String get backToConversation;

  /// No description provided for @signOutConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get signOutConfirmTitle;

  /// No description provided for @signOutConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'You will leave this workspace on this device.'**
  String get signOutConfirmBody;

  /// No description provided for @openInspectorTooltip.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get openInspectorTooltip;

  /// No description provided for @openToolsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get openToolsTooltip;

  /// No description provided for @destinationConversation.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get destinationConversation;

  /// No description provided for @destinationKnowledge.
  ///
  /// In en, this message translates to:
  /// **'Knowledge'**
  String get destinationKnowledge;

  /// No description provided for @destinationAccounting.
  ///
  /// In en, this message translates to:
  /// **'Accounting'**
  String get destinationAccounting;

  /// No description provided for @destinationDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get destinationDiagnostics;

  /// No description provided for @destinationTasks.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get destinationTasks;

  /// No description provided for @taskNewTaskHint.
  ///
  /// In en, this message translates to:
  /// **'What needs to move forward?'**
  String get taskNewTaskHint;

  /// No description provided for @taskCreateAction.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get taskCreateAction;

  /// No description provided for @taskCreatePending.
  ///
  /// In en, this message translates to:
  /// **'Adding…'**
  String get taskCreatePending;

  /// No description provided for @taskRunPending.
  ///
  /// In en, this message translates to:
  /// **'Starting…'**
  String get taskRunPending;

  /// No description provided for @taskNewProjectTitle.
  ///
  /// In en, this message translates to:
  /// **'New project'**
  String get taskNewProjectTitle;

  /// No description provided for @taskProjectNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Project name'**
  String get taskProjectNameLabel;

  /// No description provided for @taskCreateProjectAction.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get taskCreateProjectAction;

  /// No description provided for @taskMineOnlyFilter.
  ///
  /// In en, this message translates to:
  /// **'Assigned to me'**
  String get taskMineOnlyFilter;

  /// No description provided for @taskAllProjectsFilter.
  ///
  /// In en, this message translates to:
  /// **'All projects'**
  String get taskAllProjectsFilter;

  /// No description provided for @taskAllStatusesFilter.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get taskAllStatusesFilter;

  /// No description provided for @taskEmptyState.
  ///
  /// In en, this message translates to:
  /// **'No tasks yet. Add the first one below.'**
  String get taskEmptyState;

  /// No description provided for @taskUnassigned.
  ///
  /// In en, this message translates to:
  /// **'Unassigned'**
  String get taskUnassigned;

  /// No description provided for @taskChangeStatusAction.
  ///
  /// In en, this message translates to:
  /// **'Change status'**
  String get taskChangeStatusAction;

  /// No description provided for @taskStatusOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get taskStatusOpen;

  /// No description provided for @taskStatusInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get taskStatusInProgress;

  /// No description provided for @taskStatusBlocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get taskStatusBlocked;

  /// No description provided for @taskStatusDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get taskStatusDone;

  /// No description provided for @taskStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get taskStatusCancelled;

  /// No description provided for @taskSummaryTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get taskSummaryTotal;

  /// No description provided for @taskSummaryOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get taskSummaryOpen;

  /// No description provided for @taskSummaryInProgress.
  ///
  /// In en, this message translates to:
  /// **'Doing'**
  String get taskSummaryInProgress;

  /// No description provided for @taskSummaryBlocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get taskSummaryBlocked;

  /// No description provided for @taskSummaryDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get taskSummaryDone;

  /// No description provided for @unreadCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} unread'**
  String unreadCountLabel(int count);

  /// No description provided for @showCollaborationDetails.
  ///
  /// In en, this message translates to:
  /// **'Show collaboration details'**
  String get showCollaborationDetails;

  /// No description provided for @hideCollaborationDetails.
  ///
  /// In en, this message translates to:
  /// **'Hide collaboration details'**
  String get hideCollaborationDetails;

  /// No description provided for @roleOwner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get roleOwner;

  /// No description provided for @roleMaintainer.
  ///
  /// In en, this message translates to:
  /// **'Maintainer'**
  String get roleMaintainer;

  /// No description provided for @roleOperator.
  ///
  /// In en, this message translates to:
  /// **'Operator'**
  String get roleOperator;

  /// No description provided for @roleViewer.
  ///
  /// In en, this message translates to:
  /// **'Viewer'**
  String get roleViewer;

  /// No description provided for @workspaceRolePickerLabel.
  ///
  /// In en, this message translates to:
  /// **'Change member role'**
  String get workspaceRolePickerLabel;

  /// No description provided for @workspaceRoleManagerTitle.
  ///
  /// In en, this message translates to:
  /// **'Members and roles'**
  String get workspaceRoleManagerTitle;

  /// No description provided for @inspectorContext.
  ///
  /// In en, this message translates to:
  /// **'Context'**
  String get inspectorContext;

  /// No description provided for @inspectorExecution.
  ///
  /// In en, this message translates to:
  /// **'Execution'**
  String get inspectorExecution;

  /// No description provided for @agentRunsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No agent runs yet'**
  String get agentRunsEmpty;

  /// No description provided for @agentRunsRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get agentRunsRefresh;

  /// No description provided for @agentRunCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel run'**
  String get agentRunCancel;

  /// No description provided for @agentRunRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get agentRunRetry;

  /// No description provided for @agentRunApprove.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get agentRunApprove;

  /// No description provided for @agentRunReject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get agentRunReject;

  /// No description provided for @agentRunRejectReason.
  ///
  /// In en, this message translates to:
  /// **'Reason (optional)'**
  String get agentRunRejectReason;

  /// No description provided for @agentRunApprovalRequired.
  ///
  /// In en, this message translates to:
  /// **'Approval required'**
  String get agentRunApprovalRequired;

  /// No description provided for @agentRunImpact.
  ///
  /// In en, this message translates to:
  /// **'Impact'**
  String get agentRunImpact;

  /// No description provided for @agentRunTarget.
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get agentRunTarget;

  /// No description provided for @agentRunRisk.
  ///
  /// In en, this message translates to:
  /// **'Risk'**
  String get agentRunRisk;

  /// No description provided for @agentRiskReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Read only'**
  String get agentRiskReadOnly;

  /// No description provided for @agentRiskInternalWrite.
  ///
  /// In en, this message translates to:
  /// **'Internal change'**
  String get agentRiskInternalWrite;

  /// No description provided for @agentRiskExternalWrite.
  ///
  /// In en, this message translates to:
  /// **'External change'**
  String get agentRiskExternalWrite;

  /// No description provided for @agentRiskDestructive.
  ///
  /// In en, this message translates to:
  /// **'Destructive'**
  String get agentRiskDestructive;

  /// No description provided for @agentRiskUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown risk'**
  String get agentRiskUnknown;

  /// No description provided for @agentRunStepCount.
  ///
  /// In en, this message translates to:
  /// **'{count} steps'**
  String agentRunStepCount(int count);

  /// No description provided for @agentRunError.
  ///
  /// In en, this message translates to:
  /// **'Error: {message}'**
  String agentRunError(String message);

  /// No description provided for @agentRunStatusQueued.
  ///
  /// In en, this message translates to:
  /// **'Queued'**
  String get agentRunStatusQueued;

  /// No description provided for @agentRunStatusContextBuilding.
  ///
  /// In en, this message translates to:
  /// **'Gathering context'**
  String get agentRunStatusContextBuilding;

  /// No description provided for @agentRunStatusRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get agentRunStatusRunning;

  /// No description provided for @agentRunStatusWaitingApproval.
  ///
  /// In en, this message translates to:
  /// **'Waiting approval'**
  String get agentRunStatusWaitingApproval;

  /// No description provided for @agentRunStatusSucceeded.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get agentRunStatusSucceeded;

  /// No description provided for @agentRunStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get agentRunStatusFailed;

  /// No description provided for @agentRunStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get agentRunStatusCancelled;

  /// No description provided for @agentRunSourcesTitle.
  ///
  /// In en, this message translates to:
  /// **'Context sources'**
  String get agentRunSourcesTitle;

  /// No description provided for @agentRunArtifactsTitle.
  ///
  /// In en, this message translates to:
  /// **'Artifacts'**
  String get agentRunArtifactsTitle;

  /// No description provided for @agentRunsWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for approval'**
  String get agentRunsWaiting;

  /// No description provided for @destinationConnectors.
  ///
  /// In en, this message translates to:
  /// **'Connectors'**
  String get destinationConnectors;

  /// No description provided for @toolConnectorsDescription.
  ///
  /// In en, this message translates to:
  /// **'Connect mail, calendars and files on demand.'**
  String get toolConnectorsDescription;

  /// No description provided for @connectorsTitle.
  ///
  /// In en, this message translates to:
  /// **'Connectors'**
  String get connectorsTitle;

  /// No description provided for @connectorsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Credentials stay private until you share them.'**
  String get connectorsSubtitle;

  /// No description provided for @connectorAdd.
  ///
  /// In en, this message translates to:
  /// **'Add connector'**
  String get connectorAdd;

  /// No description provided for @connectorEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit connector'**
  String get connectorEdit;

  /// No description provided for @connectorName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get connectorName;

  /// No description provided for @connectorKind.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get connectorKind;

  /// No description provided for @connectorHost.
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get connectorHost;

  /// No description provided for @connectorPort.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get connectorPort;

  /// No description provided for @connectorBaseUrl.
  ///
  /// In en, this message translates to:
  /// **'Base URL'**
  String get connectorBaseUrl;

  /// No description provided for @connectorUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get connectorUsername;

  /// No description provided for @connectorPassword.
  ///
  /// In en, this message translates to:
  /// **'Password or app password'**
  String get connectorPassword;

  /// No description provided for @connectorPasswordUnchanged.
  ///
  /// In en, this message translates to:
  /// **'Leave blank to keep the stored password'**
  String get connectorPasswordUnchanged;

  /// No description provided for @connectorRead.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get connectorRead;

  /// No description provided for @connectorWrite.
  ///
  /// In en, this message translates to:
  /// **'Write (needs approval)'**
  String get connectorWrite;

  /// No description provided for @connectorSharing.
  ///
  /// In en, this message translates to:
  /// **'Sharing'**
  String get connectorSharing;

  /// No description provided for @connectorSharingPrivate.
  ///
  /// In en, this message translates to:
  /// **'Only me'**
  String get connectorSharingPrivate;

  /// No description provided for @connectorSharingWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Whole workspace'**
  String get connectorSharingWorkspace;

  /// No description provided for @connectorSharingSelected.
  ///
  /// In en, this message translates to:
  /// **'Selected people'**
  String get connectorSharingSelected;

  /// No description provided for @connectorSharedWith.
  ///
  /// In en, this message translates to:
  /// **'Shared with'**
  String get connectorSharedWith;

  /// No description provided for @connectorTest.
  ///
  /// In en, this message translates to:
  /// **'Test connection'**
  String get connectorTest;

  /// No description provided for @connectorStatusUnverified.
  ///
  /// In en, this message translates to:
  /// **'Not tested'**
  String get connectorStatusUnverified;

  /// No description provided for @connectorStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get connectorStatusActive;

  /// No description provided for @connectorStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Check failed'**
  String get connectorStatusFailed;

  /// No description provided for @connectorDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete connector'**
  String get connectorDelete;

  /// No description provided for @connectorDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}? Runs will lose access immediately.'**
  String connectorDeleteConfirm(String name);

  /// No description provided for @connectorEmpty.
  ///
  /// In en, this message translates to:
  /// **'No connectors yet'**
  String get connectorEmpty;

  /// No description provided for @connectorEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Add one so an agent can read mail or write files — writes always need your approval.'**
  String get connectorEmptyHint;

  /// No description provided for @connectorOwnerLabel.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get connectorOwnerLabel;

  /// No description provided for @connectorSharedByOther.
  ///
  /// In en, this message translates to:
  /// **'Shared with you'**
  String get connectorSharedByOther;

  /// No description provided for @connectorSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save: {error}'**
  String connectorSaveFailed(String error);

  /// No description provided for @connectorTestFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not test: {error}'**
  String connectorTestFailed(String error);

  /// No description provided for @connectorSecretsSet.
  ///
  /// In en, this message translates to:
  /// **'Stored: {fields}'**
  String connectorSecretsSet(String fields);

  /// No description provided for @connectorNoSecrets.
  ///
  /// In en, this message translates to:
  /// **'No credentials stored'**
  String get connectorNoSecrets;

  /// No description provided for @connectorNoMembers.
  ///
  /// In en, this message translates to:
  /// **'No other members'**
  String get connectorNoMembers;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @connectorFieldRequired.
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get connectorFieldRequired;

  /// No description provided for @retryLabel.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retryLabel;

  /// No description provided for @agentRunEventsTitle.
  ///
  /// In en, this message translates to:
  /// **'Execution trail'**
  String get agentRunEventsTitle;

  /// No description provided for @taskRunAgentAction.
  ///
  /// In en, this message translates to:
  /// **'Run agent'**
  String get taskRunAgentAction;

  /// No description provided for @taskRunQueued.
  ///
  /// In en, this message translates to:
  /// **'Run queued for this task'**
  String get taskRunQueued;

  /// No description provided for @toolAgentRunsDescription.
  ///
  /// In en, this message translates to:
  /// **'See what the agents are doing and what needs approval.'**
  String get toolAgentRunsDescription;

  /// No description provided for @destinationMyWork.
  ///
  /// In en, this message translates to:
  /// **'My work'**
  String get destinationMyWork;

  /// No description provided for @myWorkSubtitle.
  ///
  /// In en, this message translates to:
  /// **'What needs you now, and what is waiting on someone else.'**
  String get myWorkSubtitle;

  /// No description provided for @myWorkScopeMine.
  ///
  /// In en, this message translates to:
  /// **'For me'**
  String get myWorkScopeMine;

  /// No description provided for @myWorkScopeAll.
  ///
  /// In en, this message translates to:
  /// **'All tasks'**
  String get myWorkScopeAll;

  /// No description provided for @myWorkLaneActionable.
  ///
  /// In en, this message translates to:
  /// **'To do'**
  String get myWorkLaneActionable;

  /// No description provided for @myWorkLaneBlocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get myWorkLaneBlocked;

  /// No description provided for @myWorkLaneAwaitingOthers.
  ///
  /// In en, this message translates to:
  /// **'Waiting on others'**
  String get myWorkLaneAwaitingOthers;

  /// No description provided for @myWorkLaneRecentlyDone.
  ///
  /// In en, this message translates to:
  /// **'Recently done'**
  String get myWorkLaneRecentlyDone;

  /// No description provided for @myWorkEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing is waiting on you'**
  String get myWorkEmptyTitle;

  /// No description provided for @myWorkEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Assignments land here. Browse all tasks to pick something up.'**
  String get myWorkEmptyDescription;

  /// No description provided for @myWorkLaneEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing in this lane.'**
  String get myWorkLaneEmpty;

  /// No description provided for @myWorkErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'My work could not load'**
  String get myWorkErrorTitle;

  /// No description provided for @myWorkDueOn.
  ///
  /// In en, this message translates to:
  /// **'Due {date}'**
  String myWorkDueOn(String date);

  /// No description provided for @myWorkOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get myWorkOverdue;

  /// No description provided for @myWorkRunTooltip.
  ///
  /// In en, this message translates to:
  /// **'Open the agent run for this task'**
  String get myWorkRunTooltip;

  /// No description provided for @chatCreateTaskTooltip.
  ///
  /// In en, this message translates to:
  /// **'Turn into a task'**
  String get chatCreateTaskTooltip;

  /// No description provided for @taskFromMessageTitle.
  ///
  /// In en, this message translates to:
  /// **'New task from this message'**
  String get taskFromMessageTitle;

  /// No description provided for @taskFromMessageTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Task title'**
  String get taskFromMessageTitleLabel;

  /// No description provided for @taskFromMessageCreated.
  ///
  /// In en, this message translates to:
  /// **'Added to my work'**
  String get taskFromMessageCreated;

  /// No description provided for @myWorkLaneRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get myWorkLaneRunning;

  /// No description provided for @myWorkLaneWaitingApproval.
  ///
  /// In en, this message translates to:
  /// **'To review'**
  String get myWorkLaneWaitingApproval;

  /// No description provided for @agentRunsOfflineStatus.
  ///
  /// In en, this message translates to:
  /// **'Live updates disconnected. Checking active runs.'**
  String get agentRunsOfflineStatus;

  /// No description provided for @agentRunDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Run details'**
  String get agentRunDetailTitle;

  /// No description provided for @agentRunStepsTitle.
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get agentRunStepsTitle;

  /// No description provided for @agentRunStepsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No steps yet'**
  String get agentRunStepsEmpty;

  /// No description provided for @agentRunModelStep.
  ///
  /// In en, this message translates to:
  /// **'Agent @{agentKey}'**
  String agentRunModelStep(String agentKey);

  /// No description provided for @agentRunStepRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get agentRunStepRejected;

  /// No description provided for @agentRunEventApproved.
  ///
  /// In en, this message translates to:
  /// **'Action approved'**
  String get agentRunEventApproved;

  /// No description provided for @agentRunEventRejected.
  ///
  /// In en, this message translates to:
  /// **'Action rejected'**
  String get agentRunEventRejected;

  /// No description provided for @agentRunEventModelStarted.
  ///
  /// In en, this message translates to:
  /// **'Agent started a turn'**
  String get agentRunEventModelStarted;

  /// No description provided for @agentRunEventModelCompleted.
  ///
  /// In en, this message translates to:
  /// **'Agent completed a turn'**
  String get agentRunEventModelCompleted;

  /// No description provided for @agentRunEventToolStarted.
  ///
  /// In en, this message translates to:
  /// **'Action started'**
  String get agentRunEventToolStarted;

  /// No description provided for @agentRunEventToolCompleted.
  ///
  /// In en, this message translates to:
  /// **'Action completed'**
  String get agentRunEventToolCompleted;

  /// No description provided for @agentRunEventArtifactCreated.
  ///
  /// In en, this message translates to:
  /// **'Artifact saved'**
  String get agentRunEventArtifactCreated;

  /// No description provided for @agentRunEventUpdated.
  ///
  /// In en, this message translates to:
  /// **'Run updated'**
  String get agentRunEventUpdated;

  /// No description provided for @workspaceManagementTitle.
  ///
  /// In en, this message translates to:
  /// **'Workspace management'**
  String get workspaceManagementTitle;

  /// No description provided for @destinationWorkspaceManagement.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get destinationWorkspaceManagement;

  /// No description provided for @toolWorkspaceManagementDescription.
  ///
  /// In en, this message translates to:
  /// **'Review members and manage their roles.'**
  String get toolWorkspaceManagementDescription;

  /// No description provided for @searchConversationsHint.
  ///
  /// In en, this message translates to:
  /// **'Search conversations'**
  String get searchConversationsHint;

  /// No description provided for @noMatchingConversations.
  ///
  /// In en, this message translates to:
  /// **'No matching conversations'**
  String get noMatchingConversations;

  /// No description provided for @clearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;

  /// No description provided for @mentionAgent.
  ///
  /// In en, this message translates to:
  /// **'Mention an agent'**
  String get mentionAgent;

  /// No description provided for @composerShortcuts.
  ///
  /// In en, this message translates to:
  /// **'{modifier}+Enter to send · Enter for a new line'**
  String composerShortcuts(String modifier);

  /// No description provided for @workspaceToolsHeading.
  ///
  /// In en, this message translates to:
  /// **'Workspace tools'**
  String get workspaceToolsHeading;

  /// No description provided for @preferencesHeading.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get preferencesHeading;

  /// No description provided for @languageChinese.
  ///
  /// In en, this message translates to:
  /// **'中文'**
  String get languageChinese;

  /// No description provided for @chooseTaskGroup.
  ///
  /// In en, this message translates to:
  /// **'Choose task group'**
  String get chooseTaskGroup;

  /// No description provided for @conversationLoadError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the conversation. Try again: {error}'**
  String conversationLoadError(String error);

  /// No description provided for @switchingWorkspaceLabel.
  ///
  /// In en, this message translates to:
  /// **'Switching workspace'**
  String get switchingWorkspaceLabel;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
