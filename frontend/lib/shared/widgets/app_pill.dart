import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

class AppPill extends StatelessWidget {
  const AppPill({
    super.key,
    required this.label,
    this.value,
    this.icon,
    this.onTap,
    this.padding,
    this.backgroundColor,
    this.borderColor,
    this.labelColor,
    this.valueColor,
    this.iconColor,
    this.borderRadius,
    this.gap = AppSpacing.xs,
  });

  final String label;
  final String? value;
  final IconData? icon;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? labelColor;
  final Color? valueColor;
  final Color? iconColor;
  final BorderRadius? borderRadius;
  final double gap;

  bool get _isMetric => value != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background =
        backgroundColor ??
        theme.colorScheme.surface.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.42 : 0.92,
        );
    final border =
        borderColor ?? theme.colorScheme.outline.withValues(alpha: 0.64);
    final resolvedRadius =
        borderRadius ?? BorderRadius.circular(AppRadii.medium);
    final resolvedPadding =
        padding ??
        const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        );

    final child = Container(
      constraints: onTap == null
          ? null
          : const BoxConstraints(minHeight: 44, minWidth: 44),
      padding: resolvedPadding,
      decoration: BoxDecoration(
        color: background,
        borderRadius: resolvedRadius,
        border: Border.all(color: border),
      ),
      child: _isMetric
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value!,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: valueColor ?? theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: labelColor ?? theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ],
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 16,
                    color:
                        iconColor ??
                        labelColor ??
                        theme.colorScheme.onSurfaceVariant,
                  ),
                  SizedBox(width: gap),
                ],
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: labelColor ?? theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
    );

    if (onTap == null) {
      return child;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(borderRadius: resolvedRadius, onTap: onTap, child: child),
    );
  }
}
