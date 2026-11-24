import 'package:flutter/material.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/theme/app_tokens.dart';
import '../../domain/entities/workspace_member.dart';
import '../../domain/entities/workspace_member_role.dart';
import '../../domain/repositories/workspace_repository.dart';

/// Member list with an inline role picker.
///
/// Only an owner sees editable pickers, because the backend rejects any other
/// caller; the current user's own row stays read-only so nobody is offered an
/// action that would demote them and lock the workspace.
class WorkspaceRoleManager extends StatefulWidget {
  const WorkspaceRoleManager({
    super.key,
    required this.workspaceId,
    required this.currentUserId,
    required this.members,
    required this.repository,
    this.onMemberChanged,
  });

  final String workspaceId;
  final String currentUserId;
  final List<WorkspaceMember> members;
  final WorkspaceRepository repository;
  final ValueChanged<WorkspaceMember>? onMemberChanged;

  @override
  State<WorkspaceRoleManager> createState() => _WorkspaceRoleManagerState();
}

class _WorkspaceRoleManagerState extends State<WorkspaceRoleManager> {
  late List<WorkspaceMember> _members;
  String? _pendingUserId;
  String? _error;
  int _requestGeneration = 0;

  @override
  void initState() {
    super.initState();
    _members = widget.members;
  }

  @override
  void didUpdateWidget(covariant WorkspaceRoleManager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspaceId != widget.workspaceId ||
        oldWidget.currentUserId != widget.currentUserId ||
        !identical(oldWidget.repository, widget.repository)) {
      _requestGeneration++;
      _pendingUserId = null;
      _error = null;
    }
    if (!identical(oldWidget.members, widget.members)) {
      _members = widget.members;
    }
  }

  Future<void> _changeRole(
    WorkspaceMember member,
    WorkspaceMemberRole role,
  ) async {
    final workspaceId = widget.workspaceId;
    final current = WorkspaceMemberRole.fromStored(member.role);
    if (current == role) {
      return;
    }
    final requestGeneration = ++_requestGeneration;
    final previous = _members;
    setState(() {
      _pendingUserId = member.userId;
      _error = null;
      // Optimistic update, reverted below if the request fails.
      _members = _members
          .map(
            (entry) => entry.userId == member.userId
                ? WorkspaceMember(
                    userId: entry.userId,
                    email: entry.email,
                    displayName: entry.displayName,
                    role: role.storedValue,
                    joinedAt: entry.joinedAt,
                  )
                : entry,
          )
          .toList();
    });
    try {
      final updated = await widget.repository.changeMemberRole(
        workspaceId: workspaceId,
        userId: member.userId,
        role: role,
      );
      if (!_isCurrentRequest(requestGeneration)) {
        return;
      }
      setState(() {
        _members = _members
            .map((entry) => entry.userId == updated.userId ? updated : entry)
            .toList();
        _pendingUserId = null;
      });
      widget.onMemberChanged?.call(updated);
    } on AppException catch (error) {
      if (!_isCurrentRequest(requestGeneration)) {
        return;
      }
      setState(() {
        _members = previous;
        _pendingUserId = null;
        _error = error.message;
      });
    } catch (error) {
      if (!_isCurrentRequest(requestGeneration)) {
        return;
      }
      setState(() {
        _members = previous;
        _pendingUserId = null;
        _error = '$error';
      });
    }
  }

  bool _isCurrentRequest(int generation) =>
      mounted && generation == _requestGeneration;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final currentRole = _currentUserRole();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Text(
              _error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        for (final member in _members)
          _MemberRoleRow(
            member: member,
            l10n: l10n,
            editable:
                currentRole.canManageRoles &&
                member.userId != widget.currentUserId &&
                _pendingUserId == null,
            busy: _pendingUserId == member.userId,
            onSelected: (role) => _changeRole(member, role),
          ),
      ],
    );
  }

  WorkspaceMemberRole _currentUserRole() {
    for (final member in _members) {
      if (member.userId == widget.currentUserId) {
        return WorkspaceMemberRole.fromStored(member.role);
      }
    }
    return WorkspaceMemberRole.operator;
  }
}

class _MemberRoleRow extends StatelessWidget {
  const _MemberRoleRow({
    required this.member,
    required this.l10n,
    required this.editable,
    required this.busy,
    required this.onSelected,
  });

  final WorkspaceMember member;
  final AppLocalizations l10n;
  final bool editable;
  final bool busy;
  final ValueChanged<WorkspaceMemberRole> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final role = WorkspaceMemberRole.fromStored(member.role);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(member.displayName, style: theme.textTheme.bodyMedium),
                Text(
                  member.email,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          if (busy)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (editable)
            Semantics(
              label: l10n.workspaceRolePickerLabel,
              child: DropdownButton<WorkspaceMemberRole>(
                value: role,
                underline: const SizedBox.shrink(),
                items: [
                  for (final candidate in WorkspaceMemberRole.values)
                    DropdownMenuItem(
                      value: candidate,
                      child: Text(_roleLabel(l10n, candidate)),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    onSelected(value);
                  }
                },
              ),
            )
          else
            Text(
              _roleLabel(l10n, role),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  String _roleLabel(AppLocalizations l10n, WorkspaceMemberRole role) {
    switch (role) {
      case WorkspaceMemberRole.owner:
        return l10n.roleOwner;
      case WorkspaceMemberRole.maintainer:
        return l10n.roleMaintainer;
      case WorkspaceMemberRole.operator:
        return l10n.roleOperator;
      case WorkspaceMemberRole.viewer:
        return l10n.roleViewer;
    }
  }
}
