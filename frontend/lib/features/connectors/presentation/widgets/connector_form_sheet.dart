import 'package:material_ui/material_ui.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/theme/app_theme_extensions.dart';
import '../../../../shared/theme/app_tokens.dart';
import '../../domain/entities/agent_connector.dart';

/// Create/edit form for one connector.
///
/// Deliberately a bottom sheet rather than a dialog: on a phone the keyboard
/// plus six fields makes a centered dialog unusable, and the sheet grows to fit
/// without a second layout branch.
class ConnectorFormSheet extends StatefulWidget {
  const ConnectorFormSheet({
    super.key,
    required this.workspaceId,
    required this.members,
    this.existing,
  });

  final String workspaceId;
  final List<ConnectorMemberOption> members;
  final AgentConnector? existing;

  /// Returns the submitted draft, or null when dismissed.
  static Future<ConnectorDraft?> show(
    BuildContext context, {
    required String workspaceId,
    required List<ConnectorMemberOption> members,
    AgentConnector? existing,
  }) {
    return showModalBottomSheet<ConnectorDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ConnectorFormSheet(
        workspaceId: workspaceId,
        members: members,
        existing: existing,
      ),
    );
  }

  @override
  State<ConnectorFormSheet> createState() => _ConnectorFormSheetState();
}

class _ConnectorFormSheetState extends State<ConnectorFormSheet> {
  late ConnectorKind _kind = widget.existing?.kind ?? ConnectorKind.imap;
  late final TextEditingController _name = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late final TextEditingController _host = TextEditingController(
    text: widget.existing?.config['host'] as String? ?? '',
  );
  late final TextEditingController _port = TextEditingController(
    text: widget.existing?.config['port']?.toString() ?? '',
  );
  late final TextEditingController _baseUrl = TextEditingController(
    text: widget.existing?.config['baseUrl'] as String? ?? '',
  );
  final TextEditingController _username = TextEditingController();
  final TextEditingController _password = TextEditingController();
  late bool _readEnabled = widget.existing?.readEnabled ?? _kind.canRead;
  late bool _writeEnabled = widget.existing?.writeEnabled ?? false;
  late ConnectorSharingScope _scope =
      widget.existing?.sharingScope ?? ConnectorSharingScope.ownerOnly;
  late final Set<String> _sharedUsers = {...?widget.existing?.sharedUserIds};
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _host.dispose();
    _port.dispose();
    _baseUrl.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _isMailKind =>
      _kind == ConnectorKind.imap || _kind == ConnectorKind.smtp;

  void _submit() {
    final l10n = AppLocalizations.of(context)!;
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = l10n.connectorFieldRequired);
      return;
    }
    final config = <String, Object?>{...?widget.existing?.config};
    if (_isMailKind) {
      final host = _host.text.trim();
      if (host.isEmpty) {
        setState(() => _error = l10n.connectorFieldRequired);
        return;
      }
      config['host'] = host;
      final port = int.tryParse(_port.text.trim());
      if (port != null) {
        config['port'] = port;
      }
      config.putIfAbsent('tls', () => true);
    } else {
      final baseUrl = _baseUrl.text.trim();
      if (baseUrl.isEmpty) {
        setState(() => _error = l10n.connectorFieldRequired);
        return;
      }
      config['baseUrl'] = baseUrl;
    }
    final username = _username.text.trim();
    final password = _password.text;
    final secrets = <String, String>{
      if (username.isNotEmpty) 'username': username,
      if (password.isNotEmpty) 'password': password,
    };
    final needsSecret =
        widget.existing == null && !secrets.containsKey('password');
    if (needsSecret) {
      setState(() => _error = l10n.connectorFieldRequired);
      return;
    }
    Navigator.of(context).pop(
      ConnectorDraft(
        kind: _kind,
        name: name,
        config: config,
        // Each entered credential is a write-only patch. Omitted fields keep
        // their stored values; credentials are never prefilled on an edit.
        secrets: secrets.isEmpty ? null : secrets,
        sharingScope: _scope,
        sharedUserIds: _scope == ConnectorSharingScope.selected
            ? _sharedUsers.toList()
            : const [],
        readEnabled: _readEnabled,
        writeEnabled: _writeEnabled,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final semantic = AppSemanticColors.of(context);
    final editing = widget.existing != null;
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.sm,
        right: AppSpacing.sm,
        top: AppSpacing.sm,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.sm,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              editing ? l10n.connectorEdit : l10n.connectorAdd,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<ConnectorKind>(
              key: const Key('connector-form-kind'),
              initialValue: _kind,
              decoration: InputDecoration(
                labelText: l10n.connectorKind,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              items: [
                for (final kind in ConnectorKind.values)
                  DropdownMenuItem(value: kind, child: Text(kind.storedValue)),
              ],
              onChanged: editing
                  ? null
                  : (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        _kind = value;
                        _readEnabled = value.canRead;
                        _writeEnabled = false;
                      });
                    },
            ),
            const SizedBox(height: AppSpacing.xs),
            TextField(
              key: const Key('connector-form-name'),
              controller: _name,
              decoration: InputDecoration(
                labelText: l10n.connectorName,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            if (_isMailKind) ...[
              TextField(
                key: const Key('connector-form-host'),
                controller: _host,
                decoration: InputDecoration(
                  labelText: l10n.connectorHost,
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              TextField(
                key: const Key('connector-form-port'),
                controller: _port,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.connectorPort,
                  hintText: _kind == ConnectorKind.imap ? '993' : '587',
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
              ),
            ] else
              TextField(
                key: const Key('connector-form-baseurl'),
                controller: _baseUrl,
                decoration: InputDecoration(
                  labelText: l10n.connectorBaseUrl,
                  hintText: 'https://dav.example.com/',
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
              ),
            const SizedBox(height: AppSpacing.xs),
            TextField(
              key: const Key('connector-form-username'),
              controller: _username,
              decoration: InputDecoration(
                labelText: l10n.connectorUsername,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextField(
              key: const Key('connector-form-password'),
              controller: _password,
              obscureText: true,
              decoration: InputDecoration(
                labelText: l10n.connectorPassword,
                helperText: editing ? l10n.connectorPasswordUnchanged : null,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            SwitchListTile(
              key: const Key('connector-form-read'),
              contentPadding: EdgeInsets.zero,
              value: _readEnabled,
              onChanged: _kind.canRead
                  ? (value) => setState(() => _readEnabled = value)
                  : null,
              title: Text(l10n.connectorRead),
            ),
            SwitchListTile(
              key: const Key('connector-form-write'),
              contentPadding: EdgeInsets.zero,
              value: _writeEnabled,
              onChanged: _kind.canWrite
                  ? (value) => setState(() => _writeEnabled = value)
                  : null,
              title: Text(l10n.connectorWrite),
            ),
            const SizedBox(height: AppSpacing.xs),
            DropdownButtonFormField<ConnectorSharingScope>(
              key: const Key('connector-form-scope'),
              initialValue: _scope,
              decoration: InputDecoration(
                labelText: l10n.connectorSharing,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(
                  value: ConnectorSharingScope.ownerOnly,
                  child: Text(l10n.connectorSharingPrivate),
                ),
                DropdownMenuItem(
                  value: ConnectorSharingScope.workspace,
                  child: Text(l10n.connectorSharingWorkspace),
                ),
                DropdownMenuItem(
                  value: ConnectorSharingScope.selected,
                  child: Text(l10n.connectorSharingSelected),
                ),
              ],
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() => _scope = value);
              },
            ),
            if (_scope == ConnectorSharingScope.selected) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(l10n.connectorSharedWith, style: theme.textTheme.labelLarge),
              if (widget.members.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xxs),
                  child: Text(
                    l10n.connectorNoMembers,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                for (final member in widget.members)
                  CheckboxListTile(
                    key: Key('connector-form-member-${member.userId}'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: _sharedUsers.contains(member.userId),
                    title: Text(member.label),
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _sharedUsers.add(member.userId);
                        } else {
                          _sharedUsers.remove(member.userId);
                        }
                      });
                    },
                  ),
            ],
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: semantic.danger,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.cancel),
                ),
                const SizedBox(width: AppSpacing.xs),
                FilledButton(
                  key: const Key('connector-form-save'),
                  onPressed: _submit,
                  child: Text(l10n.save),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Minimal member view the form needs; keeps the widget independent of the
/// workspace state class so it can be tested in isolation.
class ConnectorMemberOption {
  const ConnectorMemberOption({required this.userId, required this.label});

  final String userId;
  final String label;
}
