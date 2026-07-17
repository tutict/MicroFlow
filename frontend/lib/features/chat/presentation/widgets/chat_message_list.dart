import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:microflow_frontend/l10n/app_localizations.dart';

import '../../../../core/utils/date_time_formatter.dart';
import '../../../workspace/domain/entities/knowledge_document.dart';
import '../../domain/entities/chat_message.dart';
import 'message_bubble.dart';

class ChatMessageList extends StatefulWidget {
  const ChatMessageList({
    super.key,
    required this.messages,
    required this.currentUserId,
    required this.currentUserLabel,
    this.knowledgeDocuments = const [],
    this.onKnowledgeCitationTap,
    this.compact = false,
    this.emptyIcon = Icons.forum_rounded,
    this.emptyTitle,
    this.emptyDescription,
  });

  final List<ChatMessage> messages;
  final String currentUserId;
  final String currentUserLabel;
  final List<KnowledgeDocument> knowledgeDocuments;
  final ValueChanged<String>? onKnowledgeCitationTap;
  final bool compact;
  final IconData emptyIcon;
  final String? emptyTitle;
  final String? emptyDescription;

  @override
  State<ChatMessageList> createState() => _ChatMessageListState();
}

class _ChatMessageListState extends State<ChatMessageList> {
  final GlobalKey _latestMessageKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToLatest());
  }

  @override
  void didUpdateWidget(covariant ChatMessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messages.length != oldWidget.messages.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToLatest());
    }
  }

  void _scrollToLatest() {
    final context = _latestMessageKey.currentContext;
    if (context == null) {
      return;
    }
    Scrollable.ensureVisible(
      context,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: 1,
    );
  }

  @override
  Widget build(BuildContext context) {
    final entries = _buildEntries(context);
    if (entries.isEmpty) {
      return _EmptyChatState(
        compact: widget.compact,
        icon: widget.emptyIcon,
        title: widget.emptyTitle,
        description: widget.emptyDescription,
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(widget.compact ? 10 : 18),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return switch (entry) {
          _DateDividerEntry() => Padding(
            padding: EdgeInsets.only(
              top: index == 0 ? 0 : 8,
              bottom: widget.compact ? 12 : 18,
            ),
            child: _DateDivider(label: entry.label),
          ),
          _MessageEntry() => Padding(
            padding: EdgeInsets.only(bottom: widget.compact ? 8 : 12),
            child: MessageBubble(
              key: index == entries.length - 1 ? _latestMessageKey : null,
              message: entry.message,
              isOwnMessage: entry.message.author == widget.currentUserId,
              authorLabel: _formatAuthorLabel(
                context: context,
                author: entry.message.author,
                isAgent: entry.message.isAgent,
                currentUserId: widget.currentUserId,
                currentUserLabel: widget.currentUserLabel,
              ),
              timestampLabel: _formatTimestamp(entry.message.createdAt),
              knowledgeDocuments: widget.knowledgeDocuments,
              onKnowledgeCitationTap: widget.onKnowledgeCitationTap,
              compact: widget.compact,
            ),
          ),
        };
      },
    );
  }

  List<_ChatListEntry> _buildEntries(BuildContext context) {
    final entries = <_ChatListEntry>[];
    DateTime? lastGroupDate;

    for (final message in widget.messages) {
      final parsed = DateTime.tryParse(message.createdAt)?.toLocal();
      final groupDate = parsed == null
          ? null
          : DateTime(parsed.year, parsed.month, parsed.day);

      if (groupDate != null && groupDate != lastGroupDate) {
        entries.add(
          _DateDividerEntry(_formatDateGroupLabel(context, groupDate)),
        );
        lastGroupDate = groupDate;
      }

      entries.add(_MessageEntry(message));
    }

    return entries;
  }
}

sealed class _ChatListEntry {
  const _ChatListEntry();
}

final class _DateDividerEntry extends _ChatListEntry {
  const _DateDividerEntry(this.label);

  final String label;
}

final class _MessageEntry extends _ChatListEntry {
  const _MessageEntry(this.message);

  final ChatMessage message;
}

class _DateDivider extends StatelessWidget {
  const _DateDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Divider(
            color: theme.dividerColor.withValues(alpha: 0.75),
            height: 1,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Divider(
            color: theme.dividerColor.withValues(alpha: 0.75),
            height: 1,
          ),
        ),
      ],
    );
  }
}

class _EmptyChatState extends StatelessWidget {
  const _EmptyChatState({
    required this.compact,
    required this.icon,
    this.title,
    this.description,
  });

  final bool compact;
  final IconData icon;
  final String? title;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: compact ? 28 : 34,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              Text(
                title ?? l10n.noMessagesTitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                description ?? l10n.noMessagesDescription,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatAuthorLabel({
  required BuildContext context,
  required String author,
  required bool isAgent,
  required String currentUserId,
  required String currentUserLabel,
}) {
  final l10n = AppLocalizations.of(context)!;
  if (author == currentUserId) {
    return currentUserLabel;
  }
  if (isAgent && author.startsWith('agent:')) {
    return '@${author.substring('agent:'.length)}';
  }
  if (author.startsWith('usr_')) {
    final compact = author.length > 12
        ? '${author.substring(0, 12)}...'
        : author;
    return l10n.memberLabel(compact);
  }
  return author;
}

String _formatTimestamp(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    return value;
  }
  return formatShortTimestamp(parsed.toLocal());
}

String _formatDateGroupLabel(BuildContext context, DateTime value) {
  final l10n = AppLocalizations.of(context)!;
  final locale = Localizations.localeOf(context).toLanguageTag();
  final today = DateTime.now();
  final normalizedToday = DateTime(today.year, today.month, today.day);
  final normalizedYesterday = normalizedToday.subtract(const Duration(days: 1));

  if (value == normalizedToday) {
    return l10n.todayLabel;
  }
  if (value == normalizedYesterday) {
    return l10n.yesterdayLabel;
  }
  return DateFormat.yMMMMd(locale).format(value);
}
