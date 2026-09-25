import 'dart:math' as math;

import 'package:flutter/material.dart';

double contrastRatio(Color foreground, Color background) {
  final first = _luminance(foreground);
  final second = _luminance(background);
  final hi = math.max(first, second);
  final lo = math.min(first, second);
  return (hi + 0.05) / (lo + 0.05);
}

Color blendOn(Color foreground, Color background, double alpha) {
  return Color.alphaBlend(foreground.withValues(alpha: alpha), background);
}

double _luminance(Color color) {
  return 0.2126 * _linear(color.r) +
      0.7152 * _linear(color.g) +
      0.0722 * _linear(color.b);
}

double _linear(double channel) {
  if (channel <= 0.04045) {
    return channel / 12.92;
  }
  return math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
}

final class ContrastPair {
  const ContrastPair({
    required this.name,
    required this.foreground,
    required this.background,
    required this.minimum,
  });

  final String name;
  final Color foreground;
  final Color background;
  final double minimum;
}
