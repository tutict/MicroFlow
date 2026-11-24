import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'agent_runtime_repository_provider.dart';

enum AgentReadResource { runs, events }

typedef AgentReadErrorKey = ({AgentReadResource resource, String id});

/// Read failures are independent of the last good data, so reconnecting does not hide progress.
final agentReadErrorProvider =
    NotifierProvider.family<
      AgentReadErrorController,
      Object?,
      AgentReadErrorKey
    >(AgentReadErrorController.new);

class AgentReadErrorController extends Notifier<Object?> {
  AgentReadErrorController(this.key);
  final AgentReadErrorKey key;

  @override
  Object? build() {
    ref.watch(agentRuntimeRepositoryProvider);
    return null;
  }

  void setError(Object? error) => state = error;
}
