import 'package:flutter/material.dart';
import 'package:microflow_frontend/l10n/app_localizations.dart';

import '../../../workspace/domain/entities/knowledge_document.dart';
import '../../../../shared/theme/app_theme_extensions.dart';
import '../../../../shared/theme/app_tokens.dart';
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
    final semantic = AppSemanticColors.of(context);
    final backgroundColor = isOwnMessage
        ? semantic.selectedOverlay
        : isAgent
        ? theme.colorScheme.tertiaryContainer
        : theme.colorScheme.surface;
    final borderColor = theme.dividerColor;
    final foregroundColor = theme.colorScheme.onSurface;
    final bubblePadding = compact ? AppSpacing.xs : AppSpacing.sm;
    const maxWidth = 720.0;
    final citations = _extractCitations(message.text, knowledgeDocuments);

    return Align(
      alignment: isOwnMessage ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: EdgeInsets.all(bubblePadding),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
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
                      Icon(
                        Icons.smart_toy_outlined,
                        size: 16,
                        color: theme.colorScheme.tertiary,
                      ),
                      StatusBadge(
                        label: l10n.aiBadge,
                        color: theme.colorScheme.tertiary,
                      ),
                    ],
                  ],
                ),
                Text(
                  timestampLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            SizedBox(height: compact ? AppSpacing.xs : AppSpacing.sm),
            SelectableText(
              message.text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: foregroundColor,
              ),
            ),
            if (citations.isNotEmpty) ...[
              SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: citations
                    .map(
                      (citation) => _KnowledgeCitationChip(
                        citation: citation,
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
    this.onKnowledgeCitationTap,
  });

  final _KnowledgeCitation citation;
  final ValueChanged<String>? onKnowledgeCitationTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = AppSemanticColors.of(context);
    final backgroundColor = semantic.infoContainer;
    final borderColor = theme.dividerColor;
    final labelColor = semantic.info;

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.small),
      onTap: citation.document == null && onKnowledgeCitationTap == null
          ? null
          : () => _openCitation(context),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xxs,
        ),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(AppRadii.small),
          border: Border.all(color: borderColor),
        ),
        child: Text(
          citation.label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: labelColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Future<void> _openCitation(BuildContext context) async {
    final previous = FocusManager.instance.primaryFocus;
    final document = citation.document;
    if (document != null) {
      await _showKnowledgeDocument(context, document);
      if (previous != null && previous.canRequestFocus) {
        previous.requestFocus();
      }
      return;
    }
    onKnowledgeCitationTap?.call(citation.documentId);
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
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                document.summary.isEmpty
                    ? document.contentType
                    : document.summary,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
          actions: [
            TextButton(
              autofocus: true,
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                MaterialLocalizations.of(dialogContext).closeButtonLabel,
              ),
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
