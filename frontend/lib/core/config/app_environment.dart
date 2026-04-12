final class AppEnvironment {
  const AppEnvironment._();

  static const appName = 'MicroFlow';
  static const apiBaseUrl = String.fromEnvironment(
    'MICROFLOW_API_BASE_URL',
    defaultValue: '',
  );
  static const wsBaseUrl = String.fromEnvironment(
    'MICROFLOW_WS_BASE_URL',
    defaultValue: '',
  );
}
