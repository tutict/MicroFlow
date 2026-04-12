import 'package:flutter/material.dart';

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
    this.gap = 8,
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
          alpha: theme.brightness == Brightness.dark ? 0.34 : 0.64,
        );
    final border =
        borderColor ?? theme.dividerColor.withValues(alpha: 0.82);
    final resolvedRadius =
        borderRadius ??
        BorderRadius.circular(_isMetric ? 14 : 999);
    final resolvedPadding =
        padding ??
        (_isMetric
            ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
            : const EdgeInsets.symmetric(horizontal: 12, vertical: 8));

    final child = Container(
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
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color:
                        labelColor ??
                        theme.colorScheme.onSurface.withValues(alpha: 0.68),
                    fontWeight: FontWeight.w700,
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
                        theme.colorScheme.onSurface.withValues(alpha: 0.68),
                  ),
                  SizedBox(width: gap),
                ],
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: labelColor ?? theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
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
      child: InkWell(
        borderRadius: resolvedRadius,
        onTap: onTap,
        child: child,
      ),
    );
  }
}
