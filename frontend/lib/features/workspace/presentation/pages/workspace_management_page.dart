import 'package:material_ui/material_ui.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/theme/app_tokens.dart';
import '../../domain/entities/workspace_member.dart';
import '../../domain/repositories/workspace_repository.dart';
import '../widgets/workspace_role_manager.dart';

class WorkspaceManagementPage extends StatelessWidget {
  const WorkspaceManagementPage({
    super.key,
    required this.workspaceId,
    required this.workspaceName,
    required this.currentUserId,
    required this.members,
    required this.repository,
    this.onMemberChanged,
  });
  final String workspaceId;
  final String workspaceName;
  final String currentUserId;
  final List<WorkspaceMember> members;
  final WorkspaceRepository repository;
  final ValueChanged<WorkspaceMember>? onMemberChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      key: const Key('workspace-management'),
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text(workspaceName, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        Text(
          l10n.workspaceRoleManagerTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        WorkspaceRoleManager(
          key: const Key('workspace-role-manager'),
          workspaceId: workspaceId,
          currentUserId: currentUserId,
          members: members,
          repository: repository,
          onMemberChanged: onMemberChanged,
        ),
      ],
    );
  }
}
