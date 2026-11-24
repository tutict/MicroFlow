import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/agent_approval.dart';
import '../../domain/entities/agent_artifact.dart';
import '../../domain/entities/agent_context_source.dart';
import '../../domain/entities/agent_run.dart';
import '../../domain/entities/agent_run_step.dart';
import 'agent_runtime_repository_provider.dart';

final agentRunProvider = FutureProvider.autoDispose
    .family<AgentRunSummary, String>(
      (ref, id) => ref.watch(agentRuntimeRepositoryProvider).getRun(id),
    );
final agentRunStepsProvider = FutureProvider.autoDispose
    .family<List<AgentRunStep>, String>(
      (ref, id) => ref.watch(agentRuntimeRepositoryProvider).listSteps(id),
    );
final agentRunApprovalsProvider = FutureProvider.autoDispose
    .family<List<AgentApproval>, String>(
      (ref, id) => ref
          .watch(agentRuntimeRepositoryProvider)
          .listApprovals(id, status: 'PENDING'),
    );
final agentRunContextSourcesProvider = FutureProvider.autoDispose
    .family<List<AgentContextSource>, String>(
      (ref, id) =>
          ref.watch(agentRuntimeRepositoryProvider).listContextSources(id),
    );
final agentRunArtifactsProvider = FutureProvider.autoDispose
    .family<List<AgentArtifact>, String>(
      (ref, id) => ref.watch(agentRuntimeRepositoryProvider).listArtifacts(id),
    );
