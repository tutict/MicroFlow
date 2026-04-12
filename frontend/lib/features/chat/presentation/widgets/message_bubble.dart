import 'package:flutter/material.dart';
import 'package:microflow_frontend/l10n/app_localizations.dart';

import '../../../../shared/widgets/status_badge.dart';
import '../../domain/entities/chat_message.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isOwnMessage,
    required this.authorLabel,
    required this.timestampLabel,
    this.compact = false,
  });

  final ChatMessage message;
  final bool isOwnMessage;
  final String authorLabel;
  final String timestampLabel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isAgent = message.isAgent;
    final theme = Theme.of(context);
    final backgroundColor = isOwnMessage
        ? theme.colorScheme.primary
        : isAgent
            ? theme.colorScheme.primary.withValues(alpha: theme.brightness == Brightness.dark ? 0.14 : 0.08)
            : theme.cardColor;
    final borderColor = isOwnMessage
        ? theme.colorScheme.primary
        : isAgent
            ? theme.colorScheme.primary.withValues(alpha: 0.2)
            : theme.dividerColor;
    final foregroundColor = isOwnMessage
        ? Colors.white
        : theme.colorScheme.onSurface;
    final bubblePadding = compact ? 12.0 : 16.0;
    final bubbleRadius = compact ? 14.0 : 16.0;
    final maxWidth = compact ? 560.0 : 720.0;

    return Align(
      alignment: isOwnMessage ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: EdgeInsets.all(bubblePadding),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(bubbleRadius),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: theme.brightness == Brightness.dark
                  ? const Color(0x18000000)
                  : const Color(0x120E1A22),
              blurRadius: compact ? 8 : 12,
              offset: Offset(0, compact ? 3 : 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      authorLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: (compact ? theme.textTheme.titleSmall : theme.textTheme.titleMedium)?.copyWith(
                        color: foregroundColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (isAgent) ...[
                      StatusBadge(
                        label: l10n.aiBadge,
                        color: isOwnMessage ? Colors.white : const Color(0xFF1F6F5C),
                      ),
                    ],
                  ],
                ),
                Text(
                  timestampLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isOwnMessage
                        ? Colors.white.withValues(alpha: 0.78)
                        : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            SizedBox(height: compact ? 8 : 10),
            SelectableText(
              message.text,
              style: (compact ? theme.textTheme.bodySmall : theme.textTheme.bodyMedium)?.copyWith(
                color: foregroundColor,
                height: 1.55,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
