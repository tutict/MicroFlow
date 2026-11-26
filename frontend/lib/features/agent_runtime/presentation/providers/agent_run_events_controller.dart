import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/agent_run_event.dart';
import 'agent_runtime_repository_provider.dart';
import 'agent_read_error_provider.dart';

final agentRunEventsProvider = AsyncNotifierProvider.autoDispose
    .family<AgentRunEventsController, List<AgentRunEvent>, String>(
      AgentRunEventsController.new,
    );

class AgentRunEventsController extends AsyncNotifier<List<AgentRunEvent>> {
  AgentRunEventsController(this.runId);
  static const _pageSize = 200;
  final String runId;
  List<AgentRunEvent> _trail = const [];
  int _cursor = 0;
  Future<void> _work = Future.value();
  late Future<List<AgentRunEvent>> _initialLoad;

  @override
  Future<List<AgentRunEvent>> build() {
    ref.watch(agentRuntimeRepositoryProvider);
    _initialLoad = _loadMissing();
    return _initialLoad;
  }

  Future<List<AgentRunEvent>> _loadMissing() async {
    final repository = ref.read(agentRuntimeRepositoryProvider);
    final staged = {for (final event in _trail) event.seq: event};
    var cursor = _cursor;
    while (ref.mounted) {
      final before = cursor;
      final page = await repository.listEvents(
        runId,
        afterSeq: cursor,
        limit: _pageSize,
      );
      if (!ref.mounted) return _trail;
      if (page.isEmpty) break;
      final ordered = [...page]..sort((a, b) => a.seq.compareTo(b.seq));
      for (final event in ordered) {
        if (event.seq <= cursor) continue;
        if (event.seq != cursor + 1) {
          throw StateError(
            'The run event history has a gap. Retry to recover it.',
          );
        }
        staged[event.seq] = event;
        cursor = event.seq;
      }
      if (cursor <= before) {
        throw StateError(
          'The run event history did not advance. Retry to recover it.',
        );
      }
      if (page.length < _pageSize) break;
    }
    final ordered = staged.values.toList()
      ..sort((a, b) => a.seq.compareTo(b.seq));
    _trail = List.unmodifiable(
      ordered.length > _pageSize
          ? ordered.sublist(ordered.length - _pageSize)
          : ordered,
    );
    _cursor = cursor;
    return _trail;
  }

  Future<void> accept(AgentRunEvent event) => _enqueue(() async {
    if (event.seq <= _cursor) return;
    if (event.seq != _cursor + 1) await _loadMissing();
    if (event.seq <= _cursor) return;
    if (event.seq != _cursor + 1) {
      throw StateError('The run event history has a gap. Retry to recover it.');
    }
    _cursor = event.seq;
    _trail = List.unmodifiable(
      [..._trail, event].skip(_trail.length >= _pageSize ? 1 : 0),
    );
  });

  Future<void> catchUp() => _enqueue(() async {
    await _loadMissing();
  });

  Future<void> _enqueue(Future<void> Function() action) {
    final next = _work.then((_) async {
      try {
        await _initialLoad;
      } catch (_) {
        /* A new event or manual retry can recover an initial failure. */
      }
      if (!ref.mounted) return;
      try {
        await action();
        if (ref.mounted) {
          ref
              .read(
                agentReadErrorProvider((
                  resource: AgentReadResource.events,
                  id: runId,
                )).notifier,
              )
              .setError(null);
          state = AsyncData(_trail);
        }
      } catch (error) {
        if (ref.mounted) {
          ref
              .read(
                agentReadErrorProvider((
                  resource: AgentReadResource.events,
                  id: runId,
                )).notifier,
              )
              .setError(error);
          state = AsyncData(_trail);
        }
      }
    });
    _work = next;
    return next;
  }
}
