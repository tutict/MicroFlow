import 'package:flutter/material.dart';
import 'package:microflow_frontend/l10n/app_localizations.dart';

import '../../../workspace/domain/entities/knowledge_document.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../domain/entities/chat_message.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isOwnMessage,
    required this.authorLabel,
    required this.timestampLabel,
    this.knowledgeDocuments = const [],
    this.onKnowledgeCitationTap,
    this.compact = false,
  });

  final ChatMessage message;
  final bool isOwnMessage;
  final String authorLabel;
  final String timestampLabel;
  final List<KnowledgeDocument> knowledgeDocuments;
  final ValueChanged<String>? onKnowledgeCitationTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isAgent = message.isAgent;
    final theme = Theme.of(context);
    final backgroundColor = isOwnMessage
        ? theme.colorScheme.primary
        : isAgent
        ? theme.colorScheme.primary.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.14 : 0.08,
          )
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
    final citations = _extractCitations(message.text, knowledgeDocuments);

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
                      style:
                          (compact
                                  ? theme.textTheme.titleSmall
                                  : theme.textTheme.titleMedium)
                              ?.copyWith(
                                color: foregroundColor,
                                fontWeight: FontWeight.w700,
                              ),
                    ),
                    if (isAgent) ...[
                      StatusBadge(
                        label: l10n.aiBadge,
                        color: isOwnMessage
                            ? Colors.white
                            : const Color(0xFF1F6F5C),
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
              style:
                  (compact
                          ? theme.textTheme.bodySmall
                          : theme.textTheme.bodyMedium)
                      ?.copyWith(color: foregroundColor, height: 1.55),
            ),
            if (citations.isNotEmpty) ...[
              SizedBox(height: compact ? 10 : 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: citations
                    .map(
                      (citation) => _KnowledgeCitationChip(
                        citation: citation,
                        compact: compact,
                        isOwnMessage: isOwnMessage,
                        onKnowledgeCitationTap: onKnowledgeCitationTap,
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

final class _KnowledgeCitation {
  const _KnowledgeCitation({
    required this.documentId,
    required this.label,
    required this.document,
  });

  final String documentId;
  final String label;
  final KnowledgeDocument? document;
}

class _KnowledgeCitationChip extends StatelessWidget {
  const _KnowledgeCitationChip({
    required this.citation,
    required this.compact,
    required this.isOwnMessage,
    this.onKnowledgeCitationTap,
  });

  final _KnowledgeCitation citation;
  final bool compact;
  final bool isOwnMessage;
  final ValueChanged<String>? onKnowledgeCitationTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = isOwnMessage
        ? Colors.white.withValues(alpha: 0.14)
        : theme.colorScheme.primary.withValues(alpha: 0.08);
    final borderColor = isOwnMessage
        ? Colors.white.withValues(alpha: 0.22)
        : theme.colorScheme.primary.withValues(alpha: 0.16);
    final labelColor = isOwnMessage ? Colors.white : theme.colorScheme.primary;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onKnowledgeCitationTap != null
          ? () => onKnowledgeCitationTap!(citation.documentId)
          : citation.document == null
          ? null
          : () => _showKnowledgeDocument(context, citation.document!),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 12,
          vertical: compact ? 6 : 7,
        ),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: borderColor),
        ),
        child: Text(
          citation.label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: labelColor,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Future<void> _showKnowledgeDocument(
    BuildContext context,
    KnowledgeDocument document,
  ) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          title: Text(document.fileName),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '[kb:${document.id}]',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                document.summary.isEmpty
                    ? document.contentType
                    : document.summary,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}

List<_KnowledgeCitation> _extractCitations(
  String text,
  List<KnowledgeDocument> documents,
) {
  final pattern = RegExp(r'\[kb:([A-Za-z0-9_-]+)\]');
  final seen = <String>{};
  final citations = <_KnowledgeCitation>[];

  for (final match in pattern.allMatches(text)) {
    final documentId = match.group(1);
    if (documentId == null || !seen.add(documentId)) {
      continue;
    }
    KnowledgeDocument? document;
    for (final candidate in documents) {
      if (candidate.id == documentId) {
        document = candidate;
        break;
      }
    }
    citations.add(
      _KnowledgeCitation(
        documentId: documentId,
        label: document == null ? '[kb:$documentId]' : document.fileName,
        document: document,
      ),
    );
  }
  return citations;
}
