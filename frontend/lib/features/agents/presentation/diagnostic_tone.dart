enum DiagnosticTone { success, info, warning, danger, neutral }

DiagnosticTone diagnosticToneFor(String status) {
  final normalized = status.trim().toUpperCase();
  return switch (normalized) {
    'HEALTHY' || 'REACHABLE' || 'COMPLETED' || 'OK' => DiagnosticTone.success,
    'RUNNING' || 'SIMULATED' || 'CONNECTING' => DiagnosticTone.info,
    'DEGRADED' ||
    'TIMEOUT' ||
    'TIMED_OUT' ||
    'AUTH_REQUIRED' => DiagnosticTone.warning,
    'FAILED' ||
    'ERROR' ||
    'UNREACHABLE' ||
    'UNCONFIGURED' => DiagnosticTone.danger,
    _ => DiagnosticTone.neutral,
  };
}
