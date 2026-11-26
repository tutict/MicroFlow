import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    this.initialDraft = '',
    this.onDraftChanged,
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
  final String initialDraft;
  final ValueChanged<String>? onDraftChanged;

  @override
  State<InputBox> createState() => _InputBoxState();
}

class _InputBoxState extends State<InputBox> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode(debugLabel: 'message-composer');
  String? _localErrorText;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialDraft)
      ..addListener(_draftChanged);
  }

  void _draftChanged() {
    widget.onDraftChanged?.call(_controller.text);
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(InputBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialDraft != oldWidget.initialDraft &&
        _controller.text == oldWidget.initialDraft) {
      _controller.value = TextEditingValue(
        text: widget.initialDraft,
        selection: TextSelection.collapsed(offset: widget.initialDraft.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_draftChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool get _busy => widget.isSending || _submitting;

  bool get _canSubmit =>
      widget.enabled &&
      !_busy &&
      widget.onSend != null &&
      _controller.text.trim().isNotEmpty &&
      (!_controller.value.composing.isValid ||
          _controller.value.composing.isCollapsed);

  Future<void> _submit() async {
    if (!_canSubmit) return;
    final originalDraft = _controller.text;
    setState(() {
      _submitting = true;
      _localErrorText = null;
    });
    try {
      await widget.onSend!(originalDraft.trim());
      if (mounted && _controller.text == originalDraft) _controller.clear();
    } catch (error) {
      if (mounted) setState(() => _localErrorText = error.toString());
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
        _focusNode.requestFocus();
      }
    }
  }

  void _insertMention(String mention) {
    if (_busy || !widget.enabled) return;
    final text = _controller.text;
    final selection = _controller.selection;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    final before = text.substring(0, start);
    final after = text.substring(end);
    final separator = before.isEmpty || RegExp(r'\s$').hasMatch(before)
        ? ''
        : ' ';
    final insertion = '$separator$mention ';
    _controller.value = TextEditingValue(
      text: before + insertion + after,
      selection: TextSelection.collapsed(offset: start + insertion.length),
    );
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final effectiveError = widget.errorText ?? _localErrorText;
    final modifier = theme.platform == TargetPlatform.macOS ? '⌘' : 'Ctrl';
    final hint = !widget.enabled
        ? widget.placeholderText ?? widget.helperText ?? l10n.typeMessageHint
        : _busy
        ? l10n.sendingMessage
        : widget.compact
        ? l10n.typeMessageHint
        : widget.placeholderText ?? l10n.typeMessageHint;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, control: true): _submit,
        const SingleActivator(LogicalKeyboardKey.enter, meta: true): _submit,
      },
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
            TextField(
              key: const Key('message-composer'),
              controller: _controller,
              focusNode: _focusNode,
              onChanged: (_) {
                if (_localErrorText != null) {
                  setState(() => _localErrorText = null);
                }
              },
              enabled: widget.enabled && !_busy,
              minLines: widget.compact ? 1 : 2,
              maxLines: widget.compact ? 4 : 6,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: hint,
                hintMaxLines: 2,
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerLowest,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            LayoutBuilder(
              builder: (context, constraints) {
                final iconOnly = widget.compact || constraints.maxWidth < 520;
                final showShortcut =
                    !widget.compact &&
                    constraints.maxWidth >= 680 &&
                    MediaQuery.textScalerOf(context).scale(1) <= 1.3;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xxs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (widget.suggestedMentions.isNotEmpty)
                            PopupMenuButton<String>(
                              key: const Key('composer-mention'),
                              tooltip: l10n.mentionAgent,
                              enabled: widget.enabled && !_busy,
                              icon: const Icon(
                                Icons.alternate_email_rounded,
                                size: 20,
                              ),
                              onSelected: _insertMention,
                              itemBuilder: (context) => [
                                for (final mention in widget.suggestedMentions)
                                  PopupMenuItem(
                                    value: mention,
                                    child: Text(mention),
                                  ),
                              ],
                            ),
                          if (widget.collaborationModeVisible)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
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
                                    onChanged: widget.enabled && !_busy
                                        ? widget.onCollaborationModeChanged
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          if (showShortcut)
                            Text(
                              l10n.composerShortcuts(modifier),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Tooltip(
                      message: _busy
                          ? l10n.sendingMessage
                          : l10n.composerShortcuts(modifier),
                      child: iconOnly
                          ? Semantics(
                              label: _busy ? l10n.sending : l10n.send,
                              button: true,
                              child: SizedBox.square(
                                dimension: 44,
                                child: FilledButton(
                                  key: const Key('composer-send'),
                                  onPressed: _canSubmit ? _submit : null,
                                  style: FilledButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                  ),
                                  child: _SendIcon(isSending: _busy),
                                ),
                              ),
                            )
                          : SizedBox(
                              height: 44,
                              child: FilledButton.icon(
                                key: const Key('composer-send'),
                                onPressed: _canSubmit ? _submit : null,
                                icon: _SendIcon(isSending: _busy),
                                label: Text(_busy ? l10n.sending : l10n.send),
                              ),
                            ),
                    ),
                  ],
                );
              },
            ),
            if (widget.collaborationModeVisible &&
                widget.collaborationModeEnabled &&
                widget.collaborationStatusText != null)
              Text(
                widget.collaborationStatusText!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
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
