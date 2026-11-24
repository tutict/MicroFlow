import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/app_providers.dart';
import '../../data/repositories/agent_runtime_repository_impl.dart';
import '../../domain/repositories/agent_runtime_repository.dart';

final agentRuntimeRepositoryProvider = Provider<AgentRuntimeRepository>((ref) {
  return AgentRuntimeRepositoryImpl(ref.watch(restClientProvider));
});
