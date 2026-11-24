import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/config/server_connection_keys.dart';
import '../../core/network/rest_client.dart';
import '../../core/storage/local_store.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/entities/auth_session.dart';
import '../../features/bootstrap/data/repositories/server_connection_repository_impl.dart';
import '../../features/bootstrap/domain/entities/server_connection.dart';

/// Debug-only shortcut that walks the real pairing and login flows so an
/// unfinished build can still be exercised on a device.
///
/// Nothing here forges a credential. The pairing code and the session token are
/// both issued by the running backend through the same endpoints the UI uses;
/// this only removes the manual typing. Because [isEnabled] requires
/// [kDebugMode] **and** an explicit opt-in flag, a release build can never turn
/// it on, and no credential is baked into the source.
///
/// Enable with:
/// ```
/// flutter run --dart-define=DEV_BYPASS=true \
///   --dart-define=DEV_SERVER_URL=http://192.168.1.20:8080 \
///   --dart-define=DEV_PAIRING_CODE=123456 \
///   --dart-define=DEV_EMAIL=demo@microflow.local \
///   --dart-define=DEV_PASSWORD=demo12345
/// ```
final class DevSessionBypass {
  const DevSessionBypass._();

  static const _enabledFlag = 'DEV_BYPASS';
  static const _serverUrlFlag = 'DEV_SERVER_URL';
  static const _pairingCodeFlag = 'DEV_PAIRING_CODE';
  static const _emailFlag = 'DEV_EMAIL';
  static const _passwordFlag = 'DEV_PASSWORD';

  static const _defaultEmail = 'demo@microflow.local';
  static const _defaultPassword = 'demo12345';

  /// Debug builds that opted in only.
  ///
  /// The flag is read as a *string* rather than through `bool.fromEnvironment`:
  /// in the kernel pipeline used to type-check this project, `bool.fromEnvironment`
  /// silently reported `false` even when the define was present, while
  /// `String.fromEnvironment` observed it. Reading the string keeps the gate honest
  /// in both directions, and the comparison below means only the literal `true`
  /// arms it.
  ///
  /// `bool.fromEnvironment` is also a compile-time constant, so a release build
  /// reports false regardless of flags.
  static bool get isEnabled {
    if (!kDebugMode) {
      return false;
    }
    return const String.fromEnvironment(_enabledFlag).trim().toLowerCase() ==
        'true';
  }

  /// Raw enable-flag value, exposed so tests and diagnostics can show exactly
  /// what the build passed in instead of guessing from the boolean.
  static String get enableFlagValue => const String.fromEnvironment(_enabledFlag);

  static String get serverUrl =>
      const String.fromEnvironment(_serverUrlFlag).trim();

  static String get pairingCode =>
      const String.fromEnvironment(_pairingCodeFlag).trim();

  static String get email =>
      const String.fromEnvironment(_emailFlag, defaultValue: _defaultEmail);

  static String get password =>
      const String.fromEnvironment(_passwordFlag, defaultValue: _defaultPassword);

  /// Seeds a connection and a session if the device has neither.
  ///
  /// Failures are reported rather than thrown: a misconfigured bypass should
  /// drop the developer back onto the normal connect/login screens, where the
  /// same steps can still be done by hand.
  static Future<DevBypassReport> ensureAccess() async {
    if (!isEnabled) {
      return const DevBypassReport.skipped();
    }
    if (serverUrl.isEmpty) {
      return const DevBypassReport.failed(
        'DEV_BYPASS is on but DEV_SERVER_URL is empty.',
      );
    }
    if (pairingCode.isEmpty) {
      return const DevBypassReport.failed(
        'DEV_BYPASS is on but DEV_PAIRING_CODE is empty. Fetch one from '
        'GET <server>/api/v1/bootstrap/challenge on the host.',
      );
    }

    final store = LocalStore();
    final connections = ServerConnectionRepositoryImpl(store);
    final auth = AuthRepositoryImpl(RestClient(store), store);
    final desiredOrigin = DevBypassConfig.normalizeOrigin(serverUrl);

    try {
      // Pair when there is no connection, or when the stored one points at a
      // different server than the one this run was given. Without the second
      // check a previously paired device would silently keep using the old
      // server and the bypass would look broken.
      final existing = await connections.currentConnection();
      final needsPairing = existing == null ||
          DevBypassConfig.normalizeOrigin(existing.serverOrigin) !=
              desiredOrigin;
      if (needsPairing) {
        await connections.pair(
          serverUrl: serverUrl,
          pairingCode: pairingCode,
        );
      }
      final session = await auth.currentSession() ??
          await auth.login(email: email, password: password);
      return DevBypassReport.ready(
        serverOrigin: desiredOrigin,
        displayName: session.displayName,
        paired: needsPairing,
      );
    } catch (error) {
      return DevBypassReport.failed('$error');
    }
  }
}

/// Outcome of a bypass attempt, for logging.
final class DevBypassReport {
  const DevBypassReport._({
    required this.outcome,
    this.detail = '',
  });

  const DevBypassReport.skipped()
    : this._(outcome: DevBypassOutcome.skipped);

  const DevBypassReport.ready({
    required String serverOrigin,
    required String displayName,
    required bool paired,
  }) : this._(
         outcome: DevBypassOutcome.ready,
         detail: 'server=$serverOrigin user=$displayName '
             'pairedNow=$paired',
       );

  const DevBypassReport.failed(String reason)
    : this._(outcome: DevBypassOutcome.failed, detail: reason);

  final DevBypassOutcome outcome;
  final String detail;

  bool get isReady => outcome == DevBypassOutcome.ready;

  @override
  String toString() {
    switch (outcome) {
      case DevBypassOutcome.skipped:
        return '[dev-bypass] disabled';
      case DevBypassOutcome.ready:
        return '[dev-bypass] session ready: $detail';
      case DevBypassOutcome.failed:
        return '[dev-bypass] FAILED: $detail — falling back to the normal '
            'connect and login screens.';
    }
  }
}

enum DevBypassOutcome { skipped, ready, failed }

/// Reads the pairing payload a host can fetch from
/// `GET /api/v1/bootstrap/challenge`. Kept next to the bypass so the script and
/// the app agree on field names.
final class PairingChallenge {
  const PairingChallenge({
    required this.pairingCode,
    required this.serverOrigin,
    required this.apiBaseUrl,
    required this.wsBaseUrl,
  });

  factory PairingChallenge.fromJson(Map<String, Object?> json) {
    return PairingChallenge(
      pairingCode: (json['pairingCode'] as String? ?? '').trim(),
      serverOrigin: json['serverOrigin'] as String? ?? '',
      apiBaseUrl: json['apiBaseUrl'] as String? ?? '',
      wsBaseUrl: json['wsBaseUrl'] as String? ?? '',
    );
  }

  final String pairingCode;
  final String serverOrigin;
  final String apiBaseUrl;
  final String wsBaseUrl;

  Map<String, Object?> toJson() => {
    'pairingCode': pairingCode,
    'serverOrigin': serverOrigin,
    'apiBaseUrl': apiBaseUrl,
    'wsBaseUrl': wsBaseUrl,
  };

  static PairingChallenge decode(String body) =>
      PairingChallenge.fromJson(jsonDecode(body) as Map<String, Object?>);
}

/// Pure helpers for the bypass, separated so they can be unit tested without a
/// device or a running backend.
final class DevBypassConfig {
  const DevBypassConfig._();

  /// Normalizes a host-entered server URL into the `scheme://host:port` origin
  /// the pairing endpoint expects. Mirrors the repository's own normalization so
  /// a value typed into the script behaves like one typed into the UI.
  static String normalizeOrigin(String value) {
    var normalized = value.trim();
    if (normalized.isEmpty) {
      return '';
    }
    if (!normalized.contains('://')) {
      normalized = 'http://$normalized';
    }
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  /// Whether a pairing code looks well formed before it is spent on a request.
  static bool isUsablePairingCode(String code) => code.trim().length >= 4;

  /// Whether the report describes a session the app can use.
  static bool reportIsReady(DevBypassReport report) => report.isReady;
}

/// Exposed for tests: the storage keys the bypass relies on.
final class DevBypassStorageKeys {
  const DevBypassStorageKeys._();

  static String get apiBaseUrl => ServerConnectionKeys.apiBaseUrl;
  static String get currentConnectionId =>
      ServerConnectionKeys.currentConnectionId;
}

/// Re-exported so callers do not need to import the entity just to check state.
typedef DevBypassConnection = ServerConnection;

/// Re-exported for symmetry with [DevBypassConnection].
typedef DevBypassSession = AuthSession;
