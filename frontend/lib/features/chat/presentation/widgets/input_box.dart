import 'package:flutter/material.dart';
import 'package:microflow_frontend/l10n/app_localizations.dart';

import '../../../../shared/theme/app_tokens.dart';

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
    if (value.isEmpty || widget.isSending || !widget.enabled) return;

    try {
      await widget.onSend?.call(value);
    } catch (error) {
      if (!mounted) return;
      setState(() => _localErrorText = error.toString());
      return;
    }
    if (!mounted) return;
    setState(() {
      _localErrorText = null;
      _controller.clear();
    });
  }

  void _clearLocalError() {
    if (_localErrorText == null) return;
    setState(() => _localErrorText = null);
  }

  void _insertMention(String mention) {
    if (widget.isSending || !widget.enabled) return;
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
    final effectiveError = widget.errorText ?? _localErrorText;
    final hint = !widget.enabled
        ? widget.placeholderText ?? widget.helperText ?? l10n.typeMessageHint
        : widget.isSending
        ? l10n.sendingMessage
        : widget.placeholderText ?? l10n.typeMessageHint;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.small),
      ),
      child: Padding(
        padding: EdgeInsets.all(widget.compact ? AppSpacing.xs : AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (effectiveError != null) ...[
              _ComposerError(message: l10n.messageSendFailed(effectiveError)),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (widget.enabled && widget.suggestedMentions.isNotEmpty) ...[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final mention in widget.suggestedMentions)
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.xs),
                        child: ActionChip(
                          avatar: const Icon(Icons.alternate_email, size: 16),
                          label: Text(mention),
                          onPressed: () => _insertMention(mention),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
            LayoutBuilder(
              builder: (context, constraints) {
                final iconOnly = widget.compact || constraints.maxWidth < 520;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        onChanged: (_) => _clearLocalError(),
                        enabled: widget.enabled && !widget.isSending,
                        minLines: 1,
                        maxLines: widget.compact ? 4 : 6,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          hintText: hint,
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerLowest,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.sm,
                          ),
                        ),
                      ),
                    ),
                    if (widget.collaborationModeVisible) ...[
                      const SizedBox(width: AppSpacing.xs),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 96),
                        child: Text(
                          l10n.collaborationMode,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium,
                        ),
                      ),
                      Semantics(
                        label: l10n.collaborationMode,
                        child: Switch.adaptive(
                          value: widget.collaborationModeEnabled,
                          onChanged: widget.onCollaborationModeChanged,
                        ),
                      ),
                    ],
                    const SizedBox(width: AppSpacing.sm),
                    if (iconOnly)
                      Semantics(
                        button: true,
                        label: widget.isSending ? l10n.sending : l10n.send,
                        child: SizedBox.square(
                          dimension: 44,
                          child: FilledButton(
                            onPressed: _canSubmit ? _submit : null,
                            style: FilledButton.styleFrom(
                              padding: EdgeInsets.zero,
                            ),
                            child: _SendIcon(isSending: widget.isSending),
                          ),
                        ),
                      )
                    else
                      SizedBox(
                        height: 48,
                        child: FilledButton.icon(
                          onPressed: _canSubmit ? _submit : null,
                          icon: _SendIcon(isSending: widget.isSending),
                          label: Text(
                            widget.isSending ? l10n.sending : l10n.send,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            if (widget.collaborationModeVisible &&
                widget.collaborationModeEnabled &&
                widget.collaborationStatusText != null) ...[
              const SizedBox(height: AppSpacing.xxs),
              Text(
                widget.collaborationStatusText!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool get _canSubmit => widget.enabled && !widget.isSending;
}

class _ComposerError extends StatelessWidget {
  const _ComposerError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      liveRegion: true,
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: theme.colorScheme.error,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SendIcon extends StatelessWidget {
  const _SendIcon({required this.isSending});

  final bool isSending;

  @override
  Widget build(BuildContext context) {
    if (!isSending) return const Icon(Icons.send_rounded, size: 18);
    return const SizedBox.square(
      dimension: 18,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}
