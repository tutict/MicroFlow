import 'package:flutter/material.dart';

import 'app_pill.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppPill(
      label: label,
      backgroundColor: color.withValues(alpha: 0.12),
      borderColor: color.withValues(alpha: 0.18),
      labelColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    );
  }
}
