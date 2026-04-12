import 'package:flutter/material.dart';
import 'package:microflow_frontend/l10n/app_localizations.dart';

import '../../../../shared/widgets/app_pill.dart';

class InputBox extends StatefulWidget {
  const InputBox({
    super.key,
    this.onSend,
    this.enabled = true,
    this.isSending = false,
    this.errorText,
    this.placeholderText,
    this.helperText,
    this.suggestedMentions = const [],
    this.collaborationModeVisible = false,
    this.collaborationModeEnabled = false,
    this.collaborationStatusText,
    this.onCollaborationModeChanged,
    this.compact = false,
  });

  final Future<void> Function(String value)? onSend;
  final bool enabled;
  final bool isSending;
  final String? errorText;
  final String? placeholderText;
  final String? helperText;
  final List<String> suggestedMentions;
  final bool collaborationModeVisible;
  final bool collaborationModeEnabled;
  final String? collaborationStatusText;
  final ValueChanged<bool>? onCollaborationModeChanged;
  final bool compact;

  @override
  State<InputBox> createState() => _InputBoxState();
}

class _InputBoxState extends State<InputBox> {
  late final TextEditingController _controller;
  String? _localErrorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final value = _controller.text.trim();
    if (value.isEmpty || widget.isSending || !widget.enabled) {
      return;
    }
    try {
      await widget.onSend?.call(value);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _localErrorText = error.toString();
      });
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _localErrorText = null;
      _controller.clear();
    });
  }

  void _clearLocalError() {
    if (_localErrorText == null) {
      return;
    }
    setState(() {
      _localErrorText = null;
    });
  }

  void _insertMention(String mention) {
    if (widget.isSending || !widget.enabled) {
      return;
    }

    final current = _controller.text.trimRight();
    final nextValue = current.isEmpty ? '$mention ' : '$current $mention ';
    _controller.value = TextEditingValue(
      text: nextValue,
      selection: TextSelection.collapsed(offset: nextValue.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final effectiveErrorText = widget.errorText ?? _localErrorText;
    final compactActions =
        widget.compact && widget.enabled && widget.suggestedMentions.isNotEmpty;
    final inputHint = !widget.enabled
        ? widget.placeholderText ?? widget.helperText ?? l10n.typeMessageHint
        : widget.isSending
        ? l10n.sendingMessage
        : widget.placeholderText ?? l10n.typeMessageHint;

    return Container(
      padding: EdgeInsets.fromLTRB(
        widget.compact ? 10 : 14,
        widget.compact ? 10 : 14,
        widget.compact ? 10 : 14,
        widget.compact ? 8 : 14,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(widget.compact ? 18 : 16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (effectiveErrorText != null) ...[
            Text(
              l10n.messageSendFailed(effectiveErrorText),
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFFBA3B2F),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (widget.collaborationModeVisible) ...[
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: widget.compact ? 10 : 12,
                vertical: widget.compact ? 8 : 10,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(widget.compact ? 14 : 16),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.16),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.groups_2_rounded,
                    size: widget.compact ? 16 : 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.collaborationMode,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.collaborationStatusText ??
                              l10n.collaborationModeHint,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.72,
                            ),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Switch.adaptive(
                    value: widget.collaborationModeEnabled,
                    onChanged: widget.onCollaborationModeChanged,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (compactActions) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: widget.suggestedMentions
                    .map(
                      (mention) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _MentionChip(
                          mention: mention,
                          compact: true,
                          onTap: () => _insertMention(mention),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 10),
          ] else if (widget.enabled && widget.suggestedMentions.isNotEmpty) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.quickActionsLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: widget.suggestedMentions
                        .map(
                          (mention) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _MentionChip(
                              mention: mention,
                              compact: widget.compact,
                              onTap: () => _insertMention(mention),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 420;

              if (widget.compact) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        onChanged: (_) => _clearLocalError(),
                        enabled: widget.enabled && !widget.isSending,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          hintText: inputHint,
                          filled: true,
                          isDense: true,
                          fillColor: theme.colorScheme.surface,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: FilledButton(
                        onPressed: widget.isSending || !widget.enabled
                            ? null
                            : _submit,
                        style: FilledButton.styleFrom(
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Icon(
                          widget.isSending
                              ? Icons.schedule_send
                              : Icons.send_rounded,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                );
              }

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _controller,
                      onChanged: (_) => _clearLocalError(),
                      enabled: widget.enabled && !widget.isSending,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        hintText: inputHint,
                        filled: true,
                        fillColor: theme.colorScheme.surface,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: widget.isSending || !widget.enabled
                          ? null
                          : _submit,
                      icon: Icon(
                        widget.isSending
                            ? Icons.schedule_send
                            : Icons.send_rounded,
                        size: 18,
                      ),
                      label: Text(widget.isSending ? l10n.sending : l10n.send),
                    ),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      onChanged: (_) => _clearLocalError(),
                      enabled: widget.enabled && !widget.isSending,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        hintText: inputHint,
                        filled: true,
                        fillColor: theme.colorScheme.surface,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: widget.isSending || !widget.enabled
                        ? null
                        : _submit,
                    icon: Icon(
                      widget.isSending
                          ? Icons.schedule_send
                          : Icons.send_rounded,
                      size: 18,
                    ),
                    label: Text(widget.isSending ? l10n.sending : l10n.send),
                  ),
                ],
              );
            },
          ),
          if (!widget.compact) ...[
            const SizedBox(height: 10),
            Text(
              widget.enabled
                  ? l10n.pressEnterToSend
                  : widget.helperText ?? l10n.privateConversationPreview,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.56),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MentionChip extends StatelessWidget {
  const _MentionChip({
    required this.mention,
    required this.compact,
    required this.onTap,
  });

  final String mention;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppPill(
      label: mention,
      onTap: onTap,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 10,
        vertical: compact ? 6 : 8,
      ),
      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
      borderColor: theme.colorScheme.primary.withValues(alpha: 0.18),
      labelColor: theme.colorScheme.primary,
    );
  }
}
