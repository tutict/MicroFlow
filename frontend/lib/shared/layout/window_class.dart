enum AppWindowClass { compact, medium, expanded, large }

abstract final class AppWindowClassResolver {
  static const double textScaleRelaxThreshold = 1.3;

  static AppWindowClass resolve({
    required double width,
    required double textScale,
  }) {
    final natural = width < 600
        ? AppWindowClass.compact
        : width < 1024
        ? AppWindowClass.medium
        : width < 1440
        ? AppWindowClass.expanded
        : AppWindowClass.large;
    final relaxed =
        textScale > textScaleRelaxThreshold &&
        (natural == AppWindowClass.expanded || natural == AppWindowClass.large);
    return relaxed ? AppWindowClass.medium : natural;
  }

  static bool relaxesLayout(double textScale) {
    return textScale > textScaleRelaxThreshold;
  }

  static double indexWidth(AppWindowClass windowClass) {
    return switch (windowClass) {
      AppWindowClass.compact => 0,
      AppWindowClass.medium => 280,
      AppWindowClass.expanded => 300,
      AppWindowClass.large => 320,
    };
  }
}
