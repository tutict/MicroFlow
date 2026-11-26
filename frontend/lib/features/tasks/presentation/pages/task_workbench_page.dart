import 'package:material_ui/material_ui.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/theme/app_tokens.dart';
import '../../../../shared/widgets/app_skeletons.dart';
import '../../../workspace/domain/entities/workspace_member.dart';
import '../../domain/entities/task_item.dart';
import '../../domain/entities/task_project.dart';
import '../../domain/entities/task_summary.dart';
import '../../domain/repositories/task_repository.dart';
import '../task_status_tone.dart';

class TaskWorkbenchView extends StatefulWidget {
  const TaskWorkbenchView({
    super.key,
    required this.workspaceId,
    required this.repository,
    this.members = const [],
    this.currentUserId = '',
    this.onRunAgent,
    this.showTitle = true,
  });

  final String workspaceId;
  final TaskRepository repository;

  /// Members available for task assignment.
  final List<WorkspaceMember> members;
  final String currentUserId;

  /// Starts an agent run for a task. Null hides the entry point, so the task
  /// module keeps working without the runtime wired in.
  final Future<void> Function(TaskItem task)? onRunAgent;

  /// The "my work" hub already renders a heading, so the embedded workbench
  /// drops its own instead of stacking two titles.
  final bool showTitle;

  @override
  State<TaskWorkbenchView> createState() => TaskWorkbenchViewState();
}

class TaskWorkbenchViewState extends State<TaskWorkbenchView> {
  final _titleController = TextEditingController();

  List<TaskProject> _projects = const [];
  List<TaskItem> _tasks = const [];
  TaskSummary _summary = const TaskSummary.empty();

  String? _selectedProjectId;
  String? _selectedStatus;
  bool _mineOnly = false;
  bool _isLoading = false;
  String? _error;
  int _scopeGeneration = 0;
  int _loadGeneration = 0;
  int _draftGeneration = 0;
  int _createGeneration = 0;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant TaskWorkbenchView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspaceId == widget.workspaceId &&
        identical(oldWidget.repository, widget.repository) &&
        oldWidget.currentUserId == widget.currentUserId) {
      return;
    }
    _scopeGeneration++;
    _createGeneration++;
    _creating = false;
    _projects = const [];
    _tasks = const [];
    _summary = const TaskSummary.empty();
    _selectedProjectId = null;
    _selectedStatus = null;
    _mineOnly = false;
    _titleController.clear();
    _load();
  }

  bool _isCurrentScope(int generation) =>
      mounted && generation == _scopeGeneration;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    final repository = widget.repository;
    final workspaceId = widget.workspaceId;
    final projectId = _selectedProjectId;
    final status = _selectedStatus;
    final mine = _mineOnly;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        repository.listProjects(workspaceId),
        repository.listTasks(
          workspaceId: workspaceId,
          projectId: projectId,
          status: status,
          mine: mine,
        ),
        repository.summarize(workspaceId: workspaceId, projectId: projectId),
      ]);
      if (!mounted || generation != _loadGeneration) {
        return;
      }
      setState(() {
        _projects = results[0] as List<TaskProject>;
        _tasks = results[1] as List<TaskItem>;
        _summary = results[2] as TaskSummary;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted || generation != _loadGeneration) {
        return;
      }
      setState(() {
        _error = '$error';
        _isLoading = false;
      });
    }
  }

  Future<void> _createTask() async {
    if (!mounted || _creating) return;
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      return;
    }
    final scope = _scopeGeneration;
    final draftGeneration = _draftGeneration;
    final createGeneration = ++_createGeneration;
    final repository = widget.repository;
    final workspaceId = widget.workspaceId;
    final projectId = _selectedProjectId;
    final mine = _mineOnly;
    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      await repository.createTask(
        workspaceId: workspaceId,
        title: title,
        projectId: projectId,
        assigneeIsSelf: mine,
      );
      if (!_isCurrentScope(scope)) return;
      if (_draftGeneration == draftGeneration) _titleController.clear();
      await _load();
    } catch (error) {
      if (_isCurrentScope(scope)) {
        setState(() => _error = '$error');
      }
    } finally {
      if (_isCurrentScope(scope) && createGeneration == _createGeneration) {
        setState(() => _creating = false);
      }
    }
  }

  Future<void> _setStatus(TaskItem task, String status) async {
    final scope = _scopeGeneration;
    final repository = widget.repository;
    final workspaceId = widget.workspaceId;
    if (task.workspaceId != workspaceId) return;
    try {
      await repository.updateStatus(
        workspaceId: workspaceId,
        taskId: task.id,
        status: status,
      );
      if (!_isCurrentScope(scope)) return;
      await _load();
    } catch (error) {
      if (_isCurrentScope(scope)) {
        setState(() => _error = '$error');
      }
    }
  }

  Future<void> _createProject() async {
    final scope = _scopeGeneration;
    final repository = widget.repository;
    final workspaceId = widget.workspaceId;
    final name = await showDialog<String>(
      context: context,
      builder: (context) => const _NewProjectDialog(),
    );
    if (name == null || name.isEmpty || !_isCurrentScope(scope)) {
      return;
    }
    try {
      await repository.createProject(workspaceId: workspaceId, name: name);
      if (!_isCurrentScope(scope)) return;
      await _load();
    } catch (error) {
      if (_isCurrentScope(scope)) {
        setState(() => _error = '$error');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md,
            widget.showTitle ? AppSpacing.md : AppSpacing.xs,
            AppSpacing.md,
            0,
          ),
          child: Row(
            children: [
              if (widget.showTitle)
                Expanded(
                  child: Text(
                    l10n.destinationTasks,
                    style: theme.textTheme.titleLarge,
                  ),
                )
              else
                const Spacer(),
              FilterChip(
                label: Text(l10n.taskMineOnlyFilter),
                selected: _mineOnly,
                onSelected: (value) {
                  setState(() => _mineOnly = value);
                  _load();
                },
              ),
              const SizedBox(width: AppSpacing.xs),
              IconButton(
                tooltip: l10n.taskNewProjectTitle,
                onPressed: _createProject,
                icon: const Icon(Icons.create_new_folder_outlined),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: _SummaryStrip(
            summary: _summary,
            labels: (
              total: l10n.taskSummaryTotal,
              open: l10n.taskSummaryOpen,
              inProgress: l10n.taskSummaryInProgress,
              blocked: l10n.taskSummaryBlocked,
              done: l10n.taskSummaryDone,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            children: [
              for (final status in const [
                null,
                'OPEN',
                'IN_PROGRESS',
                'BLOCKED',
                'DONE',
              ])
                _FilterChipLabel(
                  key: Key('task-status-filter-${status ?? 'ALL'}'),
                  label: status == null
                      ? l10n.taskAllStatusesFilter
                      : taskStatusPresentation(context, status).label,
                  selected: _selectedStatus == status,
                  onSelected: () {
                    setState(() => _selectedStatus = status);
                    _load();
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            children: [
              _FilterChipLabel(
                label: l10n.taskAllProjectsFilter,
                selected: _selectedProjectId == null,
                onSelected: () {
                  setState(() => _selectedProjectId = null);
                  _load();
                },
              ),
              for (final project in _projects)
                _FilterChipLabel(
                  label: '${project.name} (${project.openTaskCount})',
                  selected: _selectedProjectId == project.id,
                  onSelected: () {
                    setState(() => _selectedProjectId = project.id);
                    _load();
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(
              _error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        Expanded(
          child: _isLoading
              ? const AccountingDashboardSkeleton()
              : _tasks.isEmpty
              ? Center(child: Text(l10n.taskEmptyState))
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: _tasks.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.xs),
                  itemBuilder: (context, index) {
                    final task = _tasks[index];
                    return _TaskRow(
                      key: ValueKey((widget.workspaceId, task.id)),
                      task: task,
                      showRunAgent: widget.onRunAgent != null,
                      onAdvance: () => _setStatus(task, 'DONE'),
                      onBlock: () => _setStatus(task, 'BLOCKED'),
                      onStart: () => _setStatus(task, 'IN_PROGRESS'),
                      onRunAgent: widget.onRunAgent == null
                          ? null
                          : () => widget.onRunAgent!(task),
                    );
                  },
                ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      hintText: l10n.taskNewTaskHint,
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _createTask(),
                    onChanged: (_) => _draftGeneration++,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                FilledButton(
                  onPressed: _creating ? null : _createTask,
                  child: Text(
                    _creating ? l10n.taskCreatePending : l10n.taskCreateAction,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.summary, required this.labels});

  final TaskSummary summary;
  final ({
    String total,
    String open,
    String inProgress,
    String blocked,
    String done,
  })
  labels;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        for (final entry in <(String, int)>[
          (labels.total, summary.total),
          (labels.open, summary.open),
          (labels.inProgress, summary.inProgress),
          (labels.blocked, summary.blocked),
          (labels.done, summary.done),
        ])
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${entry.$2}', style: theme.textTheme.titleMedium),
                  Text(
                    entry.$1,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _FilterChipLabel extends StatelessWidget {
  const _FilterChipLabel({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.xs),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
      ),
    );
  }
}

class _TaskRow extends StatefulWidget {
  const _TaskRow({
    super.key,
    required this.task,
    required this.onStart,
    required this.onBlock,
    required this.onAdvance,
    this.showRunAgent = false,
    this.onRunAgent,
  });

  final TaskItem task;
  final VoidCallback onStart;
  final VoidCallback onBlock;
  final VoidCallback onAdvance;
  final bool showRunAgent;
  final Future<void> Function()? onRunAgent;

  @override
  State<_TaskRow> createState() => _TaskRowState();
}

class _TaskRowState extends State<_TaskRow> {
  bool _starting = false;
  String? _startError;

  Future<void> _select(String value) async {
    if (!mounted || _starting) return;
    if (value != 'RUN_AGENT') {
      switch (value) {
        case 'IN_PROGRESS':
          widget.onStart();
        case 'BLOCKED':
          widget.onBlock();
        case 'DONE':
          widget.onAdvance();
      }
      return;
    }
    final start = widget.onRunAgent;
    if (start == null) return;
    setState(() {
      _starting = true;
      _startError = null;
    });
    try {
      await start();
    } catch (error) {
      if (mounted) setState(() => _startError = '$error');
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final task = widget.task;
    final l10n = AppLocalizations.of(context)!;
    return Semantics(
      container: true,
      label: task.title,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadii.medium),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(task.title, style: theme.textTheme.bodyLarge),
                    const SizedBox(height: AppSpacing.xxs),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xxs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        TaskStatusBadge(task: task),
                        if (task.projectName != null)
                          Text(
                            task.projectName!,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        Icon(
                          taskPriorityIcon(task.priority),
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        Text(
                          task.isUnassigned
                              ? AppLocalizations.of(context)!.taskUnassigned
                              : task.assigneeDisplayName ?? '',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    if (_startError != null)
                      Text(
                        _startError!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                  ],
                ),
              ),
              if (!task.isDone)
                PopupMenuButton<String>(
                  tooltip: _starting
                      ? l10n.taskRunPending
                      : l10n.taskChangeStatusAction,
                  enabled: !_starting,
                  icon: _starting ? const Icon(Icons.hourglass_empty) : null,
                  onSelected: _select,
                  itemBuilder: (context) => [
                    if (task.status == 'OPEN')
                      PopupMenuItem(
                        value: 'IN_PROGRESS',
                        child: Text(
                          taskStatusPresentation(context, 'IN_PROGRESS').label,
                        ),
                      ),
                    if (task.status != 'BLOCKED')
                      PopupMenuItem(
                        value: 'BLOCKED',
                        child: Text(
                          taskStatusPresentation(context, 'BLOCKED').label,
                        ),
                      ),
                    PopupMenuItem(
                      value: 'DONE',
                      child: Text(
                        taskStatusPresentation(context, 'DONE').label,
                      ),
                    ),
                    if (widget.showRunAgent)
                      PopupMenuItem(
                        value: 'RUN_AGENT',
                        key: Key('task-run-agent-${task.id}'),
                        child: Text(
                          AppLocalizations.of(context)!.taskRunAgentAction,
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Owns its own controller so the field survives the pop animation.
class _NewProjectDialog extends StatefulWidget {
  const _NewProjectDialog();

  @override
  State<_NewProjectDialog> createState() => _NewProjectDialogState();
}

class _NewProjectDialogState extends State<_NewProjectDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text.trim());

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.taskNewProjectTitle),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(labelText: l10n.taskProjectNameLabel),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(l10n.taskCreateProjectAction),
        ),
      ],
    );
  }
}
