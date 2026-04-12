import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/app_providers.dart';
import '../../../../shared/widgets/app_pill.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../domain/entities/agent_diagnostic.dart';

final _agentDiagnosticsProvider = FutureProvider.family
    .autoDispose<List<AgentDiagnostic>, String>((ref, workspaceId) async {
      final repository = ref.watch(agentRepositoryProvider);
      return repository.listDiagnostics(workspaceId);
    });

const _maxRoleStrategyLength = 1000;

class AgentDiagnosticsPage extends ConsumerWidget {
  const AgentDiagnosticsPage({super.key, required this.workspaceId});

  final String workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final copy = _AgentDiagnosticsCopy.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(copy.title),
        actions: [
          IconButton(
            tooltip: copy.refresh,
            onPressed: workspaceId.isEmpty
                ? null
                : () => ref.invalidate(_agentDiagnosticsProvider(workspaceId)),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: theme.brightness == Brightness.dark
                ? const [
                    Color(0xFF081015),
                    Color(0xFF10191F),
                    Color(0xFF152229),
                  ]
                : const [
                    Color(0xFFF7F9F9),
                    Color(0xFFEEF2F3),
                    Color(0xFFE3EAEC),
                  ],
          ),
        ),
        child: workspaceId.isEmpty
            ? _EmptyState(message: copy.workspaceRequired)
            : ref
                  .watch(_agentDiagnosticsProvider(workspaceId))
                  .when(
                    data: (diagnostics) => _DiagnosticsList(
                      workspaceId: workspaceId,
                      diagnostics: diagnostics,
                    ),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, _) =>
                        _EmptyState(message: '${copy.loadFailed}: $error'),
                  ),
      ),
    );
  }
}

class _DiagnosticsList extends ConsumerWidget {
  const _DiagnosticsList({
    required this.workspaceId,
    required this.diagnostics,
  });

  final String workspaceId;
  final List<AgentDiagnostic> diagnostics;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final copy = _AgentDiagnosticsCopy.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: theme.brightness == Brightness.dark
                  ? const [Color(0xFF162229), Color(0xFF111C22)]
                  : const [Color(0xFFFCFDFD), Color(0xFFF2F6F7)],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.82),
            ),
            boxShadow: [
              BoxShadow(
                color: theme.brightness == Brightness.dark
                    ? const Color(0x26000000)
                    : const Color(0x140E1A22),
                blurRadius: 24,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                copy.title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                copy.subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  AppPill(
                    label: '${copy.workspace}: $workspaceId',
                    icon: Icons.hub_rounded,
                    backgroundColor: theme.colorScheme.surface.withValues(
                      alpha: theme.brightness == Brightness.dark ? 0.34 : 0.64,
                    ),
                    borderColor: theme.dividerColor.withValues(alpha: 0.82),
                    labelColor: theme.colorScheme.onSurface.withValues(
                      alpha: 0.76,
                    ),
                    iconColor: theme.colorScheme.primary,
                  ),
                  AppPill(
                    label: '${copy.agents}: ${diagnostics.length}',
                    icon: Icons.smart_toy_rounded,
                    backgroundColor: theme.colorScheme.surface.withValues(
                      alpha: theme.brightness == Brightness.dark ? 0.34 : 0.64,
                    ),
                    borderColor: theme.dividerColor.withValues(alpha: 0.82),
                    labelColor: theme.colorScheme.onSurface.withValues(
                      alpha: 0.76,
                    ),
                    iconColor: const Color(0xFF1F8A5C),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...diagnostics.map(
          (diagnostic) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _DiagnosticCard(
              diagnostic: diagnostic,
              onEditRoleStrategy: () async {
                final updated = await _showRoleStrategyEditor(
                  context: context,
                  ref: ref,
                  workspaceId: workspaceId,
                  diagnostic: diagnostic,
                );
                if (updated) {
                  ref.invalidate(_agentDiagnosticsProvider(workspaceId));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(copy.roleStrategySaved)),
                    );
                  }
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _DiagnosticCard extends StatelessWidget {
  const _DiagnosticCard({
    required this.diagnostic,
    required this.onEditRoleStrategy,
  });

  final AgentDiagnostic diagnostic;
  final Future<void> Function() onEditRoleStrategy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final copy = _AgentDiagnosticsCopy.of(context);
    final statusColor = _statusColor(diagnostic.status);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.34 : 0.72,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.82)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.health_and_safety_rounded,
                  color: statusColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '@${diagnostic.agentKey}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        StatusBadge(
                          label: _statusLabel(copy, diagnostic.status),
                          color: statusColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      diagnostic.detail.isEmpty ? '-' : diagnostic.detail,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.68,
                        ),
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _DiagnosticRow(label: copy.provider, value: diagnostic.provider),
          _DiagnosticRow(
            label: copy.endpoint,
            value: diagnostic.endpointUrl.isEmpty
                ? '-'
                : diagnostic.endpointUrl,
          ),
          _DiagnosticRow(
            label: copy.credential,
            value: diagnostic.credentialConfigured
                ? copy.configured
                : copy.notConfigured,
          ),
          _DiagnosticRow(
            label: copy.enabled,
            value: diagnostic.enabled ? copy.yes : copy.no,
          ),
          _DiagnosticRow(
            label: copy.roleStrategy,
            value: diagnostic.roleStrategy.isEmpty
                ? copy.defaultRoleStrategy
                : diagnostic.roleStrategy,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: onEditRoleStrategy,
              icon: const Icon(Icons.edit_note_rounded, size: 18),
              label: Text(copy.editRoleStrategy),
            ),
          ),
          _DiagnosticRow(
            label: copy.latency,
            value: diagnostic.latencyMillis > 0
                ? '${diagnostic.latencyMillis} ms'
                : '-',
          ),
          _DiagnosticRow(
            label: copy.checkedAt,
            value: diagnostic.checkedAt.isEmpty ? '-' : diagnostic.checkedAt,
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'HEALTHY':
      case 'REACHABLE':
        return const Color(0xFF1E8E5A);
      case 'SIMULATED':
        return const Color(0xFF3D7EA6);
      case 'AUTH_REQUIRED':
      case 'DEGRADED':
        return const Color(0xFFC86A3B);
      case 'DISABLED':
        return const Color(0xFF7A8791);
      case 'UNCONFIGURED':
      case 'UNREACHABLE':
      default:
        return const Color(0xFFB23A48);
    }
  }

  String _statusLabel(_AgentDiagnosticsCopy copy, String status) {
    switch (status) {
      case 'HEALTHY':
        return copy.healthy;
      case 'REACHABLE':
        return copy.reachable;
      case 'SIMULATED':
        return copy.simulated;
      case 'AUTH_REQUIRED':
        return copy.authRequired;
      case 'DEGRADED':
        return copy.degraded;
      case 'DISABLED':
        return copy.disabled;
      case 'UNCONFIGURED':
        return copy.unconfigured;
      case 'UNREACHABLE':
      default:
        return copy.unreachable;
    }
  }
}

Future<bool> _showRoleStrategyEditor({
  required BuildContext context,
  required WidgetRef ref,
  required String workspaceId,
  required AgentDiagnostic diagnostic,
}) async {
  final copy = _AgentDiagnosticsCopy.of(context);
  final templates = _roleStrategyTemplates(copy);
  final recommendedTemplate = _recommendedRoleStrategyTemplate(
    diagnostic.agentKey,
    templates,
  );
  final controller = TextEditingController(text: diagnostic.roleStrategy);
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      var isSaving = false;
      String? errorText;
      return StatefulBuilder(
        builder: (context, setState) {
          Future<void> save() async {
            setState(() {
              isSaving = true;
              errorText = null;
            });
            try {
              await ref
                  .read(agentRepositoryProvider)
                  .updateRoleStrategy(
                    workspaceId: workspaceId,
                    agentKey: diagnostic.agentKey,
                    roleStrategy: controller.text,
                  );
              if (context.mounted) {
                Navigator.of(context).pop(true);
              }
            } catch (error) {
              setState(() {
                errorText = error.toString();
                isSaving = false;
              });
            }
          }

          void applyTemplate(String value) {
            controller.value = TextEditingValue(
              text: value,
              selection: TextSelection.collapsed(offset: value.length),
            );
            setState(() {});
          }

          ButtonStyle templateStyle(_RoleStrategyTemplate template) {
            final currentTemplate = _selectedRoleStrategyTemplate(
              controller.text,
              templates,
            );
            final matchesCurrent = identical(currentTemplate, template);
            final isRecommended = identical(template, recommendedTemplate);
            if (!matchesCurrent && !isRecommended) {
              return OutlinedButton.styleFrom();
            }
            final color = isRecommended
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.secondary;
            return OutlinedButton.styleFrom(
              side: BorderSide(color: color, width: 1.4),
              foregroundColor: color,
              backgroundColor: matchesCurrent
                  ? color.withValues(alpha: 0.12)
                  : null,
            );
          }

          final currentTemplate = _selectedRoleStrategyTemplate(
            controller.text,
            templates,
          );
          final matchesRecommended =
              recommendedTemplate != null &&
              identical(currentTemplate, recommendedTemplate);
          final useDefaultSelected = controller.text.trim().isEmpty;

          return AlertDialog(
            scrollable: true,
            title: Text('${copy.editRoleStrategy} @${diagnostic.agentKey}'),
            content: SizedBox(
              width: 560,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    copy.roleStrategyHint,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (recommendedTemplate != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primaryContainer.withValues(alpha: 0.34),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.32),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            copy.recommendedTemplate,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            copy.recommendedTemplateFor(
                              diagnostic.agentKey,
                              recommendedTemplate.label,
                            ),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilledButton.tonalIcon(
                                onPressed: isSaving
                                    ? null
                                    : () => applyTemplate(
                                        recommendedTemplate.strategy,
                                      ),
                                icon: const Icon(Icons.auto_awesome_rounded),
                                label: Text(copy.applyRecommended),
                              ),
                              if (matchesRecommended)
                                Chip(
                                  avatar: const Icon(
                                    Icons.check_circle_rounded,
                                    size: 18,
                                  ),
                                  label: Text(copy.currentlyApplied),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    copy.templates,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final template in templates)
                        OutlinedButton.icon(
                          style: templateStyle(template),
                          onPressed: isSaving
                              ? null
                              : () => applyTemplate(template.strategy),
                          icon: Icon(
                            identical(currentTemplate, template)
                                ? Icons.check_circle_rounded
                                : identical(recommendedTemplate, template)
                                ? Icons.auto_awesome_rounded
                                : Icons.label_outline_rounded,
                            size: 18,
                          ),
                          label: Text(template.label),
                        ),
                      OutlinedButton.icon(
                        style: useDefaultSelected
                            ? OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.secondary,
                                  width: 1.4,
                                ),
                                foregroundColor: Theme.of(
                                  context,
                                ).colorScheme.secondary,
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.secondary.withValues(alpha: 0.12),
                              )
                            : null,
                        onPressed: isSaving ? null : () => applyTemplate(''),
                        icon: Icon(
                          useDefaultSelected
                              ? Icons.check_circle_rounded
                              : Icons.undo_rounded,
                          size: 18,
                        ),
                        label: Text(copy.useDefaultStrategy),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    enabled: !isSaving,
                    maxLength: _maxRoleStrategyLength,
                    minLines: 5,
                    maxLines: 9,
                    decoration: InputDecoration(
                      labelText: copy.roleStrategy,
                      hintText: copy.roleStrategyFieldHint,
                    ),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      errorText!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFFBA3B2F),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving
                    ? null
                    : () => Navigator.of(context).pop(false),
                child: Text(copy.cancel),
              ),
              FilledButton(
                onPressed: isSaving ? null : save,
                child: Text(isSaving ? copy.saving : copy.save),
              ),
            ],
          );
        },
      );
    },
  );
  return result ?? false;
}

List<_RoleStrategyTemplate> _roleStrategyTemplates(_AgentDiagnosticsCopy copy) {
  return [
    _RoleStrategyTemplate(
      kind: _RoleStrategyTemplateKind.synthesizer,
      label: copy.synthesizerTemplate,
      strategy:
          'You are the synthesizer. Reconcile the thread, surface consensus, and keep the team response concise.',
    ),
    _RoleStrategyTemplate(
      kind: _RoleStrategyTemplateKind.reviewer,
      label: copy.reviewerTemplate,
      strategy:
          'You are the critic. Focus on risks, contradictions, edge cases, and what should be corrected.',
    ),
    _RoleStrategyTemplate(
      kind: _RoleStrategyTemplateKind.planner,
      label: copy.plannerTemplate,
      strategy:
          'You are the planner. Provide structure, sequencing, and the minimum viable path to execution.',
    ),
    _RoleStrategyTemplate(
      kind: _RoleStrategyTemplateKind.implementer,
      label: copy.implementerTemplate,
      strategy:
          'You are the implementer. Convert ideas into concrete actions, interfaces, and delivery details.',
    ),
    _RoleStrategyTemplate(
      kind: _RoleStrategyTemplateKind.releaseCaptain,
      label: copy.releaseTemplate,
      strategy:
          'You are the release captain. Focus on launch sequencing, dependencies, and readiness gates.',
    ),
  ];
}

_RoleStrategyTemplate? _recommendedRoleStrategyTemplate(
  String agentKey,
  List<_RoleStrategyTemplate> templates,
) {
  final normalized = agentKey.trim().toLowerCase();
  if (normalized.contains('review') ||
      normalized.contains('critic') ||
      normalized.contains('qa') ||
      normalized.contains('test')) {
    return _templateByKind(templates, _RoleStrategyTemplateKind.reviewer);
  }
  if (normalized.contains('architect') ||
      normalized.contains('plan') ||
      normalized.contains('lead') ||
      normalized.contains('strategy')) {
    return _templateByKind(templates, _RoleStrategyTemplateKind.planner);
  }
  if (normalized.contains('build') ||
      normalized.contains('coder') ||
      normalized.contains('dev') ||
      normalized.contains('implement')) {
    return _templateByKind(templates, _RoleStrategyTemplateKind.implementer);
  }
  if (normalized.contains('release') ||
      normalized.contains('deploy') ||
      normalized.contains('ops') ||
      normalized.contains('launch')) {
    return _templateByKind(templates, _RoleStrategyTemplateKind.releaseCaptain);
  }
  if (normalized.contains('assistant') ||
      normalized.contains('summar') ||
      normalized.contains('facilitator')) {
    return _templateByKind(templates, _RoleStrategyTemplateKind.synthesizer);
  }
  return null;
}

_RoleStrategyTemplate? _selectedRoleStrategyTemplate(
  String roleStrategy,
  List<_RoleStrategyTemplate> templates,
) {
  final normalized = roleStrategy.trim();
  if (normalized.isEmpty) {
    return null;
  }
  for (final template in templates) {
    if (template.strategy == normalized) {
      return template;
    }
  }
  return null;
}

_RoleStrategyTemplate? _templateByKind(
  List<_RoleStrategyTemplate> templates,
  _RoleStrategyTemplateKind kind,
) {
  for (final template in templates) {
    if (template.kind == kind) {
      return template;
    }
  }
  return null;
}

class _RoleStrategyTemplate {
  const _RoleStrategyTemplate({
    required this.kind,
    required this.label,
    required this.strategy,
  });

  final _RoleStrategyTemplateKind kind;
  final String label;
  final String strategy;
}

enum _RoleStrategyTemplateKind {
  synthesizer,
  reviewer,
  planner,
  implementer,
  releaseCaptain,
}

class _DiagnosticRow extends StatelessWidget {
  const _DiagnosticRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 126,
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
          ),
        ),
      ),
    );
  }
}

class _AgentDiagnosticsCopy {
  const _AgentDiagnosticsCopy({
    required this.title,
    required this.subtitle,
    required this.refresh,
    required this.workspaceRequired,
    required this.loadFailed,
    required this.workspace,
    required this.agents,
    required this.provider,
    required this.endpoint,
    required this.credential,
    required this.roleStrategy,
    required this.defaultRoleStrategy,
    required this.editRoleStrategy,
    required this.roleStrategyHint,
    required this.roleStrategySaved,
    required this.enabled,
    required this.latency,
    required this.checkedAt,
    required this.configured,
    required this.notConfigured,
    required this.yes,
    required this.no,
    required this.healthy,
    required this.reachable,
    required this.simulated,
    required this.authRequired,
    required this.degraded,
    required this.disabled,
    required this.unconfigured,
    required this.unreachable,
    required this.save,
    required this.saving,
    required this.cancel,
    required this.roleStrategyFieldHint,
    required this.templates,
    required this.useDefaultStrategy,
    required this.recommendedTemplate,
    required this.applyRecommended,
    required this.currentlyApplied,
    required this.synthesizerTemplate,
    required this.reviewerTemplate,
    required this.plannerTemplate,
    required this.implementerTemplate,
    required this.releaseTemplate,
    required this.isChinese,
  });

  final String title;
  final String subtitle;
  final String refresh;
  final String workspaceRequired;
  final String loadFailed;
  final String workspace;
  final String agents;
  final String provider;
  final String endpoint;
  final String credential;
  final String roleStrategy;
  final String defaultRoleStrategy;
  final String editRoleStrategy;
  final String roleStrategyHint;
  final String roleStrategySaved;
  final String enabled;
  final String latency;
  final String checkedAt;
  final String configured;
  final String notConfigured;
  final String yes;
  final String no;
  final String healthy;
  final String reachable;
  final String simulated;
  final String authRequired;
  final String degraded;
  final String disabled;
  final String unconfigured;
  final String unreachable;
  final String save;
  final String saving;
  final String cancel;
  final String roleStrategyFieldHint;
  final String templates;
  final String useDefaultStrategy;
  final String recommendedTemplate;
  final String applyRecommended;
  final String currentlyApplied;
  final String synthesizerTemplate;
  final String reviewerTemplate;
  final String plannerTemplate;
  final String implementerTemplate;
  final String releaseTemplate;
  final bool isChinese;

  String recommendedTemplateFor(String agentKey, String templateLabel) {
    if (isChinese) {
      return '@$agentKey '
          '\u5efa\u8bae\u4f7f\u7528"$templateLabel"'
          '\u6a21\u677f\u3002';
    }
    return '@$agentKey is best matched with the $templateLabel template.';
  }

  static _AgentDiagnosticsCopy of(BuildContext context) {
    final isChinese = Localizations.localeOf(context).languageCode == 'zh';
    if (isChinese) {
      return const _AgentDiagnosticsCopy(
        title: '\u0041gent \u8bca\u65ad',
        subtitle:
            '\u67e5\u770b\u5f53\u524d\u5de5\u4f5c\u533a\u91cc\u6bcf\u4e2a Agent '
            '\u7684 provider\u3001endpoint\u3001\u8ba4\u8bc1\u72b6\u6001\uff0c'
            '\u4ee5\u53ca\u53ef\u7f16\u8f91\u7684\u534f\u4f5c\u89d2\u8272\u7b56\u7565\u3002',
        refresh: '\u5237\u65b0',
        workspaceRequired:
            '\u7f3a\u5c11 workspace\uff0c\u4e0a\u4e0b\u6587\u5c1a\u672a\u51c6'
            '\u5907\u597d\uff0c\u6682\u65f6\u65e0\u6cd5\u52a0\u8f7d Agent \u8bca\u65ad\u3002',
        loadFailed: '\u52a0\u8f7d\u8bca\u65ad\u5931\u8d25',
        workspace: '\u5de5\u4f5c\u533a',
        agents: 'Agent',
        provider: 'Provider',
        endpoint: 'Endpoint',
        credential: '\u8ba4\u8bc1',
        roleStrategy: '\u89d2\u8272\u7b56\u7565',
        defaultRoleStrategy:
            '\u4f7f\u7528\u7cfb\u7edf\u9ed8\u8ba4\u63a8\u65ad\u7b56\u7565',
        editRoleStrategy: '\u7f16\u8f91\u89d2\u8272\u7b56\u7565',
        roleStrategyHint:
            '\u7559\u7a7a\u65f6\u4f7f\u7528\u7cfb\u7edf\u9ed8\u8ba4\u63a8\u65ad'
            '\uff1b\u586b\u5199\u540e\u4f1a\u5728\u591a Agent \u534f\u4f5c\u65f6'
            '\u76f4\u63a5\u4f5c\u4e3a\u8be5 Agent \u7684\u89d2\u8272\u63d0\u793a\u3002',
        roleStrategySaved: '\u89d2\u8272\u7b56\u7565\u5df2\u66f4\u65b0',
        enabled: '\u542f\u7528',
        latency: '\u5ef6\u8fdf',
        checkedAt: '\u68c0\u67e5\u65f6\u95f4',
        configured: '\u5df2\u914d\u7f6e',
        notConfigured: '\u672a\u914d\u7f6e',
        yes: '\u662f',
        no: '\u5426',
        healthy: '\u5065\u5eb7',
        reachable: '\u53ef\u8fbe',
        simulated: '\u6a21\u62df',
        authRequired: '\u9700\u8981\u8ba4\u8bc1',
        degraded: '\u5f02\u5e38',
        disabled: '\u5df2\u7981\u7528',
        unconfigured: '\u672a\u914d\u7f6e',
        unreachable: '\u4e0d\u53ef\u8fbe',
        save: '\u4fdd\u5b58',
        saving: '\u4fdd\u5b58\u4e2d...',
        cancel: '\u53d6\u6d88',
        roleStrategyFieldHint:
            '\u4f8b\u5982\uff1a\u4f60\u662f\u5ba1\u7a3f\u4eba\uff0c\u4e13\u6ce8'
            '\u98ce\u9669\u3001\u53cd\u4f8b\u548c\u9700\u8981\u7ea0\u6b63\u7684\u90e8\u5206\u3002',
        templates: '\u6a21\u677f\u5e93',
        useDefaultStrategy: '\u6062\u590d\u9ed8\u8ba4',
        recommendedTemplate: '\u63a8\u8350\u6a21\u677f',
        applyRecommended: '\u5e94\u7528\u63a8\u8350',
        currentlyApplied: '\u5f53\u524d\u5df2\u5e94\u7528',
        synthesizerTemplate: '\u7efc\u5408\u8005',
        reviewerTemplate: '\u5ba1\u67e5\u8005',
        plannerTemplate: '\u89c4\u5212\u8005',
        implementerTemplate: '\u6267\u884c\u8005',
        releaseTemplate: '\u53d1\u5e03\u8d1f\u8d23\u4eba',
        isChinese: true,
      );
    }
    return const _AgentDiagnosticsCopy(
      title: 'Agent Diagnostics',
      subtitle:
          'Review the provider, endpoint, credential state, and editable collaboration role strategy for each agent in this workspace.',
      refresh: 'Refresh',
      workspaceRequired:
          'No workspace context is available yet, so diagnostics cannot be loaded.',
      loadFailed: 'Failed to load diagnostics',
      workspace: 'Workspace',
      agents: 'Agents',
      provider: 'Provider',
      endpoint: 'Endpoint',
      credential: 'Credential',
      roleStrategy: 'Role strategy',
      defaultRoleStrategy: 'Using inferred default strategy',
      editRoleStrategy: 'Edit role strategy',
      roleStrategyHint:
          'Leave blank to use the built-in heuristic. When provided, this text is injected directly into multi-agent collaboration prompts for this agent.',
      roleStrategySaved: 'Role strategy updated',
      enabled: 'Enabled',
      latency: 'Latency',
      checkedAt: 'Checked at',
      configured: 'Configured',
      notConfigured: 'Not configured',
      yes: 'Yes',
      no: 'No',
      healthy: 'Healthy',
      reachable: 'Reachable',
      simulated: 'Simulated',
      authRequired: 'Auth required',
      degraded: 'Degraded',
      disabled: 'Disabled',
      unconfigured: 'Unconfigured',
      unreachable: 'Unreachable',
      save: 'Save',
      saving: 'Saving...',
      cancel: 'Cancel',
      roleStrategyFieldHint:
          'Example: You are the reviewer. Focus on risks, counterexamples, and what should be corrected.',
      templates: 'Templates',
      useDefaultStrategy: 'Use default',
      recommendedTemplate: 'Recommended template',
      applyRecommended: 'Apply recommended',
      currentlyApplied: 'Currently applied',
      synthesizerTemplate: 'Synthesizer',
      reviewerTemplate: 'Reviewer',
      plannerTemplate: 'Planner',
      implementerTemplate: 'Implementer',
      releaseTemplate: 'Release captain',
      isChinese: false,
    );
  }
}
