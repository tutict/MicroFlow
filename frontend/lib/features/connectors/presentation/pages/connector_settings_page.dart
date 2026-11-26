import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/theme/app_theme_extensions.dart';
import '../../../../shared/theme/app_tokens.dart';
import '../../domain/entities/agent_connector.dart';
import '../providers/connector_providers.dart';
import '../widgets/connector_form_sheet.dart';

/// Workspace connector settings.
///
/// The list never renders a credential and never offers to reveal one: the
/// server only ever sends the names of stored secret fields, so "password is
/// set" is the strongest statement this screen can honestly make.
class ConnectorSettingsPage extends ConsumerStatefulWidget {
  const ConnectorSettingsPage({
    super.key,
    required this.workspaceId,
    this.members = const [],
  });

  final String workspaceId;
  final List<ConnectorMemberOption> members;

  @override
  ConsumerState<ConnectorSettingsPage> createState() =>
      _ConnectorSettingsPageState();
}

class _ConnectorSettingsPageState extends ConsumerState<ConnectorSettingsPage> {
  /// Ids currently being tested, so the row can show progress instead of
  /// silently doing nothing for several seconds on a slow DAV server.
  final Set<String> _testing = {};
  String? _inlineError;

  Future<void> _openForm({AgentConnector? existing}) async {
    final draft = await ConnectorFormSheet.show(
      context,
      workspaceId: widget.workspaceId,
      members: widget.members,
      existing: existing,
    );
    if (draft == null || !mounted) {
      return;
    }
    final actions = ref.read(connectorActionsProvider);
    try {
      if (existing == null) {
        await actions.create(widget.workspaceId, draft);
      } else {
        await actions.update(widget.workspaceId, existing.id, draft);
      }
      if (mounted) {
        setState(() => _inlineError = null);
      }
    } catch (error) {
      if (mounted) {
        setState(
          () =>
              _inlineError = AppLocalizations.of(context)!
                  .connectorSaveFailed(_messageOf(error)),
        );
      }
    }
  }

  Future<void> _test(AgentConnector connector) async {
    setState(() => _testing.add(connector.id));
    final l10n = AppLocalizations.of(context)!;
    try {
      final check = await ref
          .read(connectorActionsProvider)
          .test(widget.workspaceId, connector.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            check.detail ??
                (check.status == ConnectorStatus.active
                    ? l10n.connectorStatusActive
                    : l10n.connectorStatusFailed),
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(
          () => _inlineError = l10n.connectorTestFailed(_messageOf(error)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _testing.remove(connector.id));
      }
    }
  }

  Future<void> _delete(AgentConnector connector) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.connectorDelete),
        content: Text(l10n.connectorDeleteConfirm(connector.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            key: const Key('connector-delete-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.connectorDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    try {
      await ref
          .read(connectorActionsProvider)
          .delete(widget.workspaceId, connector.id);
    } catch (error) {
      if (mounted) {
        setState(() => _inlineError = _messageOf(error));
      }
    }
  }

  String _messageOf(Object error) {
    final text = error.toString();
    return text.startsWith('AppException: ')
        ? text.substring('AppException: '.length)
        : text;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final connectors = ref.watch(connectorsProvider(widget.workspaceId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.xs,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.connectorsTitle,
                      style: theme.textTheme.titleMedium,
                    ),
                    Text(
                      l10n.connectorsSubtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                key: const Key('connector-add'),
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(l10n.connectorAdd),
              ),
            ],
          ),
        ),
        if (_inlineError != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Text(
              _inlineError!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppSemanticColors.of(context).danger,
              ),
            ),
          ),
        Expanded(
          child: connectors.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _ErrorState(
              message: _messageOf(error),
              onRetry: () =>
                  ref.invalidate(connectorsProvider(widget.workspaceId)),
            ),
            data: (items) {
              if (items.isEmpty) {
                return _EmptyState(onAdd: () => _openForm());
              }
              return ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.sm),
                itemCount: items.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.xs),
                itemBuilder: (context, index) {
                  final connector = items[index];
                  return _ConnectorTile(
                    connector: connector,
                    testing: _testing.contains(connector.id),
                    onEdit: () => _openForm(existing: connector),
                    onTest: () => _test(connector),
                    onDelete: () => _delete(connector),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ConnectorTile extends StatelessWidget {
  const _ConnectorTile({
    required this.connector,
    required this.testing,
    required this.onEdit,
    required this.onTest,
    required this.onDelete,
  });

  final AgentConnector connector;
  final bool testing;
  final VoidCallback onEdit;
  final VoidCallback onTest;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Card(
      key: Key('connector-tile-${connector.id}'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    connector.name,
                    style: theme.textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _StatusChip(status: connector.status),
              ],
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              '${connector.kind.storedValue} · ${connector.endpointLabel()}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.xxs),
            Wrap(
              spacing: AppSpacing.xxs,
              runSpacing: AppSpacing.xxs,
              children: [
                if (connector.readEnabled) _Badge(label: l10n.connectorRead),
                if (connector.writeEnabled)
                  _Badge(label: l10n.connectorWrite, emphasized: true),
                _Badge(label: _sharingLabel(l10n, connector)),
                _Badge(
                  label: connector.hasCredentials
                      ? l10n.connectorSecretsSet(
                          connector.secretFields.join(', '),
                        )
                      : l10n.connectorNoSecrets,
                ),
                if (!connector.ownedByMe)
                  _Badge(label: l10n.connectorSharedByOther),
              ],
            ),
            if (connector.lastError != null &&
                connector.lastError!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xxs),
              Text(
                connector.lastError!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppSemanticColors.of(context).danger,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: AppSpacing.xxs,
              children: [
                TextButton(
                  key: Key('connector-test-${connector.id}'),
                  onPressed: testing ? null : onTest,
                  child: testing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.connectorTest),
                ),
                if (connector.ownedByMe)
                  TextButton(
                    key: Key('connector-edit-${connector.id}'),
                    onPressed: onEdit,
                    child: Text(l10n.connectorEdit),
                  ),
                if (connector.ownedByMe)
                  TextButton(
                    key: Key('connector-delete-${connector.id}'),
                    onPressed: onDelete,
                    child: Text(l10n.connectorDelete),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _sharingLabel(AppLocalizations l10n, AgentConnector connector) {
    return switch (connector.sharingScope) {
      ConnectorSharingScope.ownerOnly => l10n.connectorSharingPrivate,
      ConnectorSharingScope.workspace => l10n.connectorSharingWorkspace,
      ConnectorSharingScope.selected => l10n.connectorSharingSelected,
    };
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final ConnectorStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final semantic = AppSemanticColors.of(context);
    final (label, color) = switch (status) {
      ConnectorStatus.active => (l10n.connectorStatusActive, semantic.success),
      ConnectorStatus.failed => (l10n.connectorStatusFailed, semantic.danger),
      ConnectorStatus.unverified => (
        l10n.connectorStatusUnverified,
        Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, size: 8, color: color),
        const SizedBox(width: AppSpacing.xxs),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, this.emphasized = false});

  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = emphasized
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadii.small),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(color: color),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.hub_outlined,
                size: 40,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(l10n.connectorEmpty, style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                l10n.connectorEmptyHint,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              FilledButton.icon(
                key: const Key('connector-empty-add'),
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(l10n.connectorAdd),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppSemanticColors.of(context).danger,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              key: const Key('connector-retry'),
              onPressed: onRetry,
              child: Text(l10n.retryLabel),
            ),
          ],
        ),
      ),
    );
  }
}
