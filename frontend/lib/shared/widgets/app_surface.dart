import 'package:flutter/material.dart';

enum AppSurfaceVariant { base, muted, raised, selected }

class AppSurface extends StatelessWidget {
  const AppSurface({
    super.key,
    required this.child,
    this.variant = AppSurfaceVariant.base,
    this.padding,
    this.margin,
    this.borderRadius = 8,
    this.accentColor,
    this.onTap,
    this.minInteractiveSize = false,
    this.clipBehavior = Clip.none,
    this.width,
    this.height,
  });

  final Widget child;
  final AppSurfaceVariant variant;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? accentColor;
  final VoidCallback? onTap;
  final bool minInteractiveSize;
  final Clip clipBehavior;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(borderRadius);
    final accent = accentColor ?? theme.colorScheme.primary;
    final decoration = BoxDecoration(
      color: switch (variant) {
        AppSurfaceVariant.base => theme.colorScheme.surface,
        AppSurfaceVariant.muted =>
          theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.24 : 0.5,
          ),
        AppSurfaceVariant.raised => theme.colorScheme.surface,
        AppSurfaceVariant.selected => accent.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.18 : 0.1,
        ),
      },
      borderRadius: radius,
      border: Border.all(
        color: switch (variant) {
          AppSurfaceVariant.selected => accent.withValues(alpha: 0.22),
          _ => theme.dividerColor,
        },
      ),
      boxShadow: variant == AppSurfaceVariant.raised
          ? [
              BoxShadow(
                color: theme.brightness == Brightness.dark
                    ? const Color(0x24000000)
                    : const Color(0x0D0F1720),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ]
          : null,
    );

    final content = Padding(
      padding: padding ?? EdgeInsets.zero,
      child: minInteractiveSize
          ? ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Align(alignment: Alignment.centerLeft, child: child),
            )
          : child,
    );

    if (onTap == null) {
      return Container(
        width: width,
        height: height,
        margin: margin,
        clipBehavior: clipBehavior,
        decoration: decoration,
        child: content,
      );
    }

    return Container(
      width: width,
      height: height,
      margin: margin,
      clipBehavior: clipBehavior,
      decoration: decoration,
      child: Material(
        color: Colors.transparent,
        child: InkWell(borderRadius: radius, onTap: onTap, child: content),
      ),
    );
  }
}
