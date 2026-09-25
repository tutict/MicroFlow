import 'package:flutter/material.dart';
import 'package:microflow_frontend/l10n/app_localizations.dart';

import '../../../../shared/theme/app_theme_extensions.dart';
import '../../../../shared/theme/app_tokens.dart';

class InspectorPerson {
  const InspectorPerson({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

class WorkspaceInspector extends StatefulWidget {
  const WorkspaceInspector({
    super.key,
    required this.title,
    required this.description,
    required this.participants,
    required this.collaborationSummary,
    required this.onOpenKnowledge,
  });

  final String title;
  final String description;
  final List<InspectorPerson> participants;
  final String? collaborationSummary;
  final VoidCallback onOpenKnowledge;

  @override
  State<WorkspaceInspector> createState() => _WorkspaceInspectorState();
}

class _WorkspaceInspectorState extends State<WorkspaceInspector> {
  bool _currentOpen = true;
  bool _collaborationOpen = false;
  bool _knowledgeOpen = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final muted = AppSemanticColors.of(context).mutedSurface;
    return ColoredBox(
      color: muted,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.sm),
        children: [
          _Section(
            title: l10n.inspectorCurrent,
            expanded: _currentOpen,
            onChanged: (value) => setState(() => _currentOpen = value),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.title, style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  widget.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                for (final person in widget.participants)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Row(
                      children: [
                        Icon(person.icon, size: 20),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            person.label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          _Section(
            title: l10n.inspectorCollaboration,
            expanded: _collaborationOpen,
            onChanged: (value) => setState(() => _collaborationOpen = value),
            child: Text(
              widget.collaborationSummary ?? l10n.idle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
          _Section(
            title: l10n.inspectorKnowledge,
            expanded: _knowledgeOpen,
            onChanged: (value) => setState(() => _knowledgeOpen = value),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: widget.onOpenKnowledge,
                icon: const Icon(Icons.library_books_outlined, size: 20),
                label: Text(l10n.destinationKnowledge),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.expanded,
    required this.onChanged,
    required this.child,
  });

  final String title;
  final bool expanded;
  final ValueChanged<bool> onChanged;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadii.medium),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () => onChanged(!expanded),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: expanded
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                      Icon(
                        expanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (expanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm,
                  0,
                  AppSpacing.sm,
                  AppSpacing.sm,
                ),
                child: child,
              ),
          ],
        ),
      ),
    );
  }
}
