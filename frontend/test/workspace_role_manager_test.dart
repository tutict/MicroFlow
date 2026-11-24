import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microflow_frontend/app/theme/app_theme.dart';
import 'package:microflow_frontend/core/errors/app_exception.dart';
import 'package:microflow_frontend/features/chat/domain/entities/channel_summary.dart';
import 'package:microflow_frontend/features/workspace/domain/entities/knowledge_document.dart';
import 'package:microflow_frontend/features/workspace/domain/entities/workspace_conversation.dart';
import 'package:microflow_frontend/features/workspace/domain/entities/workspace_member.dart';
import 'package:microflow_frontend/features/workspace/domain/entities/workspace_member_role.dart';
import 'package:microflow_frontend/features/workspace/domain/entities/workspace_summary.dart';
import 'package:microflow_frontend/features/workspace/domain/repositories/workspace_repository.dart';
import 'package:microflow_frontend/features/workspace/presentation/widgets/workspace_role_manager.dart';
import 'package:microflow_frontend/l10n/app_localizations.dart';

void main() {
  for (final outcome in ['success', 'app error', 'unexpected error']) {
    testWidgets(
      'an obsolete role $outcome cannot affect a new request after A-B-A',
      (tester) async {
        final obsolete = Completer<WorkspaceMember>();
        final latest = Completer<WorkspaceMember>();
        final changes = <WorkspaceMember>[];
        final repository = _FakeRoleRepository(
          pendingResponses: [obsolete.future, latest.future],
        );
        Widget manager(String workspaceId, String mateRole) => _host(
          WorkspaceRoleManager(
            workspaceId: workspaceId,
            currentUserId: 'usr_owner',
            repository: repository,
            onMemberChanged: changes.add,
            members: [
              const WorkspaceMember(
                userId: 'usr_owner',
                email: 'owner@example.com',
                displayName: 'Owner',
                role: 'OWNER',
                joinedAt: '2026-01-01',
              ),
              WorkspaceMember(
                userId: 'usr_mate',
                email: 'mate@example.com',
                displayName: 'Teammate',
                role: mateRole,
                joinedAt: '2026-01-01',
              ),
            ],
          ),
        );
        await tester.pumpWidget(manager('ws_a', 'OPERATOR'));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(DropdownButton<WorkspaceMemberRole>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Maintainer').last);
        await tester.pump();
        await tester.pumpWidget(manager('ws_b', 'VIEWER'));
        await tester.pumpWidget(manager('ws_a', 'VIEWER'));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(DropdownButton<WorkspaceMemberRole>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Operator').last);
        await tester.pump();

        if (outcome == 'success') {
          obsolete.complete(_roleResponse('MAINTAINER'));
        } else if (outcome == 'app error') {
          obsolete.completeError(const AppException('obsolete role failure'));
        } else {
          obsolete.completeError(StateError('obsolete role failure'));
        }
        await tester.pump();
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.textContaining('obsolete role failure'), findsNothing);
        expect(changes, isEmpty);

        latest.complete(_roleResponse('OPERATOR'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<DropdownButton<WorkspaceMemberRole>>(
                find.byType(DropdownButton<WorkspaceMemberRole>),
              )
              .value,
          WorkspaceMemberRole.operator,
        );
        expect(changes.map((member) => member.role), ['OPERATOR']);
      },
    );
  }

  testWidgets(
    'an old role response cannot overwrite roles after a workspace switch',
    (tester) async {
      final response = Completer<WorkspaceMember>();
      final repository = _FakeRoleRepository(pendingResponse: response.future);
      Widget manager(String workspaceId, String mateRole) => _host(
        WorkspaceRoleManager(
          workspaceId: workspaceId,
          currentUserId: 'usr_owner',
          repository: repository,
          members: [
            const WorkspaceMember(
              userId: 'usr_owner',
              email: 'owner@example.com',
              displayName: 'Owner',
              role: 'OWNER',
              joinedAt: '2026-01-01',
            ),
            WorkspaceMember(
              userId: 'usr_mate',
              email: 'mate@example.com',
              displayName: 'Teammate',
              role: mateRole,
              joinedAt: '2026-01-01',
            ),
          ],
        ),
      );
      await tester.pumpWidget(manager('ws_1', 'OPERATOR'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButton<WorkspaceMemberRole>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Maintainer').last);
      await tester.pump();
      await tester.pumpWidget(manager('ws_2', 'VIEWER'));
      response.complete(
        const WorkspaceMember(
          userId: 'usr_mate',
          email: 'mate@example.com',
          displayName: 'Teammate',
          role: 'MAINTAINER',
          joinedAt: '2026-01-01',
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DropdownButton<WorkspaceMemberRole>>(
              find.byType(DropdownButton<WorkspaceMemberRole>),
            )
            .value,
        WorkspaceMemberRole.viewer,
      );
    },
  );

  test('role enum maps stored values and tolerates legacy input', () {
    expect(WorkspaceMemberRole.fromStored('OWNER'), WorkspaceMemberRole.owner);
    expect(
      WorkspaceMemberRole.fromStored('maintainer'),
      WorkspaceMemberRole.maintainer,
    );
    expect(
      WorkspaceMemberRole.fromStored('MEMBER'),
      WorkspaceMemberRole.operator,
      reason: 'the legacy MEMBER value must land on operator',
    );
    expect(WorkspaceMemberRole.fromStored(null), WorkspaceMemberRole.operator);
    expect(
      WorkspaceMemberRole.fromStored('nonsense'),
      WorkspaceMemberRole.operator,
    );
    expect(WorkspaceMemberRole.owner.canManageRoles, isTrue);
    expect(WorkspaceMemberRole.maintainer.canManageRoles, isFalse);
  });

  testWidgets('owner sees editable pickers for other members', (tester) async {
    final repository = _FakeRoleRepository();
    await tester.pumpWidget(
      _host(
        WorkspaceRoleManager(
          workspaceId: 'ws_1',
          currentUserId: 'usr_owner',
          members: const [
            WorkspaceMember(
              userId: 'usr_owner',
              email: 'owner@example.com',
              displayName: 'Owner',
              role: 'OWNER',
              joinedAt: '2026-01-01',
            ),
            WorkspaceMember(
              userId: 'usr_mate',
              email: 'mate@example.com',
              displayName: 'Teammate',
              role: 'OPERATOR',
              joinedAt: '2026-01-01',
            ),
          ],
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DropdownButton<WorkspaceMemberRole>), findsOneWidget);
    expect(find.text('Teammate'), findsOneWidget);
  });

  testWidgets('a non-owner sees no editable picker', (tester) async {
    final repository = _FakeRoleRepository();
    await tester.pumpWidget(
      _host(
        WorkspaceRoleManager(
          workspaceId: 'ws_1',
          currentUserId: 'usr_mate',
          members: const [
            WorkspaceMember(
              userId: 'usr_owner',
              email: 'owner@example.com',
              displayName: 'Owner',
              role: 'OWNER',
              joinedAt: '2026-01-01',
            ),
            WorkspaceMember(
              userId: 'usr_mate',
              email: 'mate@example.com',
              displayName: 'Teammate',
              role: 'OPERATOR',
              joinedAt: '2026-01-01',
            ),
          ],
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DropdownButton<WorkspaceMemberRole>), findsNothing);
    expect(repository.changeRequests, isEmpty);
  });

  testWidgets('owner cannot demote themselves through the picker', (
    tester,
  ) async {
    final repository = _FakeRoleRepository();
    await tester.pumpWidget(
      _host(
        WorkspaceRoleManager(
          workspaceId: 'ws_1',
          currentUserId: 'usr_owner',
          members: const [
            WorkspaceMember(
              userId: 'usr_owner',
              email: 'owner@example.com',
              displayName: 'Owner',
              role: 'OWNER',
              joinedAt: '2026-01-01',
            ),
            WorkspaceMember(
              userId: 'usr_mate',
              email: 'mate@example.com',
              displayName: 'Teammate',
              role: 'OPERATOR',
              joinedAt: '2026-01-01',
            ),
          ],
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Exactly one picker exists, and it belongs to the other member's row.
    expect(find.byType(DropdownButton<WorkspaceMemberRole>), findsOneWidget);
    final picker = tester.widget<DropdownButton<WorkspaceMemberRole>>(
      find.byType(DropdownButton<WorkspaceMemberRole>),
    );
    expect(picker.value, WorkspaceMemberRole.operator);
  });

  testWidgets('a rejected role change reverts the optimistic update', (
    tester,
  ) async {
    final repository = _FakeRoleRepository(shouldFail: true);
    await tester.pumpWidget(
      _host(
        WorkspaceRoleManager(
          workspaceId: 'ws_1',
          currentUserId: 'usr_owner',
          members: const [
            WorkspaceMember(
              userId: 'usr_owner',
              email: 'owner@example.com',
              displayName: 'Owner',
              role: 'OWNER',
              joinedAt: '2026-01-01',
            ),
            WorkspaceMember(
              userId: 'usr_mate',
              email: 'mate@example.com',
              displayName: 'Teammate',
              role: 'OPERATOR',
              joinedAt: '2026-01-01',
            ),
          ],
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButton<WorkspaceMemberRole>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Viewer').last);
    await tester.pumpAndSettle();

    expect(repository.changeRequests, isNotEmpty);
    expect(find.textContaining('forbidden'), findsOneWidget);
    final picker = tester.widget<DropdownButton<WorkspaceMemberRole>>(
      find.byType(DropdownButton<WorkspaceMemberRole>),
    );
    expect(
      picker.value,
      WorkspaceMemberRole.operator,
      reason: 'a refused change must not leave the row showing the new role',
    );
  });
}

Widget _host(Widget child) {
  return MaterialApp(
    theme: AppTheme.light(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

WorkspaceMember _roleResponse(String role) => WorkspaceMember(
  userId: 'usr_mate',
  email: 'mate@example.com',
  displayName: 'Teammate',
  role: role,
  joinedAt: '2026-01-01',
);

class _FakeRoleRepository implements WorkspaceRepository {
  _FakeRoleRepository({
    this.shouldFail = false,
    this.pendingResponse,
    this.pendingResponses,
  });

  final bool shouldFail;
  final Future<WorkspaceMember>? pendingResponse;
  final List<Future<WorkspaceMember>>? pendingResponses;
  final List<String> changeRequests = [];

  @override
  Future<WorkspaceMember> changeMemberRole({
    required String workspaceId,
    required String userId,
    required WorkspaceMemberRole role,
  }) async {
    changeRequests.add('$userId -> ${role.storedValue}');
    if (pendingResponses?.isNotEmpty ?? false) {
      return pendingResponses!.removeAt(0);
    }
    if (pendingResponse != null) return pendingResponse!;
    if (shouldFail) {
      throw const AppException('forbidden: only owners may change roles');
    }
    return WorkspaceMember(
      userId: userId,
      email: 'mate@example.com',
      displayName: 'Teammate',
      role: role.storedValue,
      joinedAt: '2026-01-01',
    );
  }

  @override
  Future<List<WorkspaceMember>> listMembers(String workspaceId) async =>
      const [];

  @override
  Future<List<WorkspaceMember>> addMemberByEmail({
    required String workspaceId,
    required String email,
  }) async => const [];

  @override
  Future<List<WorkspaceSummary>> listWorkspaces() async => const [];

  @override
  Future<WorkspaceSummary> createWorkspace(String name) async {
    throw UnimplementedError();
  }

  @override
  Future<List<ChannelSummary>> listChannels(String workspaceId) async =>
      const [];

  @override
  Future<List<WorkspaceConversation>> listConversations(
    String workspaceId,
  ) async => const [];

  @override
  Future<List<KnowledgeDocument>> listKnowledgeDocuments(
    String workspaceId,
  ) async => const [];

  @override
  Future<KnowledgeDocument> uploadKnowledgeDocument({
    required String workspaceId,
    required String fileName,
    required Uint8List bytes,
    String? channelId,
  }) async {
    throw UnimplementedError();
  }
}
