import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../layout/window_class.dart';
import '../theme/app_tokens.dart';

class AppLoadingScaffold extends StatelessWidget {
  const AppLoadingScaffold({super.key, this.title, this.child});

  final String? title;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: title == null ? null : AppBar(title: Text(title!)),
      body: child ?? const AppPageSkeleton(),
    );
  }
}

class AppPageSkeleton extends StatelessWidget {
  const AppPageSkeleton({
    super.key,
    this.sectionCount = 3,
    this.showHeader = true,
    this.showSidebar = false,
  });

  final int sectionCount;
  final bool showHeader;
  final bool showSidebar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final windowClass = AppWindowClassResolver.resolve(
      width: MediaQuery.sizeOf(context).width,
      textScale: MediaQuery.textScalerOf(context).scale(1),
    );
    final isWide = windowClass != AppWindowClass.compact;
    final sections = List<Widget>.generate(
      sectionCount,
      (index) => _SkeletonSection(lines: index == 0 ? 4 : 3),
    );

    final content = Padding(
      padding: EdgeInsets.all(isWide ? AppSpacing.md : AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showHeader) ...[
            _SkeletonBlock(
              height: isWide ? 112 : 104,
              borderRadius: AppRadii.medium,
              child: const _SkeletonHeader(),
            ),
            SizedBox(height: isWide ? 16 : 12),
          ],
          Expanded(
            child: isWide && showSidebar
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(width: 300, child: _SkeletonColumn()),
                      const SizedBox(width: 16),
                      Expanded(child: _SkeletonList(sections: sections)),
                    ],
                  )
                : _SkeletonList(sections: sections),
          ),
        ],
      ),
    );

    return ColoredBox(
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        top: false,
        child: Skeletonizer(enabled: true, child: content),
      ),
    );
  }
}

class WorkspaceHomeSkeleton extends StatelessWidget {
  const WorkspaceHomeSkeleton({
    super.key,
    required this.compact,
    required this.showAgents,
  });

  final bool compact;
  final bool showAgents;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return const AppPageSkeleton(sectionCount: 4);
    }
    return AppPageSkeleton(sectionCount: 4, showSidebar: showAgents);
  }
}

class AccountingDashboardSkeleton extends StatelessWidget {
  const AccountingDashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppPageSkeleton(sectionCount: 5, showHeader: true);
  }
}

class AgentDiagnosticsSkeleton extends StatelessWidget {
  const AgentDiagnosticsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppPageSkeleton(sectionCount: 4, showHeader: true);
  }
}

class _SkeletonList extends StatelessWidget {
  const _SkeletonList({required this.sections});

  final List<Widget> sections;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: sections.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) => sections[index],
    );
  }
}

class _SkeletonColumn extends StatelessWidget {
  const _SkeletonColumn();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: 5,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) => const _SkeletonSection(lines: 2),
    );
  }
}

class _SkeletonHeader extends StatelessWidget {
  const _SkeletonHeader();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _SkeletonLine(width: 220, height: 20),
        SizedBox(height: 12),
        _SkeletonLine(width: double.infinity, height: 14),
        SizedBox(height: 8),
        _SkeletonLine(width: 260, height: 14),
      ],
    );
  }
}

class _SkeletonSection extends StatelessWidget {
  const _SkeletonSection({required this.lines});

  final int lines;

  @override
  Widget build(BuildContext context) {
    return _SkeletonBlock(
      height: 96 + (lines * 12),
      borderRadius: AppRadii.medium,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _SkeletonLine(width: 180, height: 18),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < lines; i++) ...[
            _SkeletonLine(
              width: i == lines - 1 ? 220 : double.infinity,
              height: 12,
            ),
            if (i != lines - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({
    required this.child,
    required this.height,
    required this.borderRadius,
  });

  final Widget child;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: height,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: theme.dividerColor),
      ),
      child: child,
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface,
        borderRadius: BorderRadius.circular(AppRadii.small),
      ),
    );
  }
}
