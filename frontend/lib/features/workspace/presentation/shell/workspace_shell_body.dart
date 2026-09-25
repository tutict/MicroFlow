import 'package:flutter/material.dart';

import '../../../../shared/layout/window_class.dart';
import '../../../../shared/theme/app_tokens.dart';

class WorkspaceShellBody extends StatelessWidget {
  const WorkspaceShellBody({
    super.key,
    required this.windowClass,
    required this.index,
    required this.canvas,
    required this.inspector,
    required this.showIndex,
    required this.showInspector,
  });

  final AppWindowClass windowClass;
  final Widget index;
  final Widget canvas;
  final Widget inspector;
  final bool showIndex;
  final bool showInspector;

  @override
  Widget build(BuildContext context) {
    if (!showIndex || windowClass == AppWindowClass.compact) {
      return canvas;
    }
    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FocusTraversalOrder(
            order: const NumericFocusOrder(2),
            child: SizedBox(
              width: AppWindowClassResolver.indexWidth(windowClass),
              child: index,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: FocusTraversalOrder(
              order: const NumericFocusOrder(3),
              child: canvas,
            ),
          ),
          if (showInspector) ...[
            const SizedBox(width: AppSpacing.sm),
            FocusTraversalOrder(
              order: const NumericFocusOrder(4),
              child: SizedBox(
                key: const Key('workspace-inspector'),
                width: 320,
                child: inspector,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
