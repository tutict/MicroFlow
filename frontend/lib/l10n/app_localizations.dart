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
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'MicroFlow'**
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
  /// **'Sign in to MicroFlow'**
  String get signInTitle;

  /// No description provided for @signInDescription.
  ///
  /// In en, this message translates to:
  /// **'Connect the local workspace, authenticate, then start real-time collaboration.'**
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
  /// **'Focused collaboration workspace for local AI execution, encrypted storage, and lightweight delivery.'**
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
  /// **'Private thread with AI coworker'**
  String get agentConversationHint;

  /// No description provided for @privateConversationPreview.
  ///
  /// In en, this message translates to:
  /// **'Private conversation entry is ready in the UI. Backend conversation APIs are the next step.'**
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
  /// **'A shared team conversation with AI support available through @mention when needed.'**
  String get chatPanelDescription;

  /// No description provided for @noMessagesTitle.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get noMessagesTitle;

  /// No description provided for @noMessagesDescription.
  ///
  /// In en, this message translates to:
  /// **'Start the conversation with a team update, then mention an agent only when you need help.'**
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
  /// **'Agent Runs'**
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
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'zh': return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
