import 'package:flutter_test/flutter_test.dart';
import 'package:microflow_frontend/core/dev/dev_session_bypass.dart';

void main() {
  group('origin normalization', () {
    test('adds a scheme when the host omits it', () {
      expect(
        DevBypassConfig.normalizeOrigin('192.168.1.20:8080'),
        'http://192.168.1.20:8080',
      );
    });

    test('keeps an explicit scheme', () {
      expect(
        DevBypassConfig.normalizeOrigin('https://flow.example.com'),
        'https://flow.example.com',
      );
    });

    test('strips trailing slashes so the join stays well formed', () {
      expect(
        DevBypassConfig.normalizeOrigin('http://10.0.2.2:8080///'),
        'http://10.0.2.2:8080',
      );
    });

    test('treats whitespace-only input as absent', () {
      expect(DevBypassConfig.normalizeOrigin('   '), '');
    });
  });

  group('pairing code validation', () {
    test('rejects a code that is too short to be real', () {
      expect(DevBypassConfig.isUsablePairingCode('12'), isFalse);
      expect(DevBypassConfig.isUsablePairingCode(''), isFalse);
      expect(DevBypassConfig.isUsablePairingCode('   '), isFalse);
    });

    test('accepts a plausible code, trimming surrounding space', () {
      expect(DevBypassConfig.isUsablePairingCode('  482913 '), isTrue);
    });
  });

  group('report interpretation', () {
    test('a skipped report is not ready', () {
      const report = DevBypassReport.skipped();
      expect(DevBypassConfig.reportIsReady(report), isFalse);
      expect(report.toString(), contains('disabled'));
    });

    test('a ready report carries the server and the signed-in user', () {
      const report = DevBypassReport.ready(
        serverOrigin: 'http://10.0.2.2:8080',
        displayName: 'Demo Builder',
        paired: true,
      );
      expect(DevBypassConfig.reportIsReady(report), isTrue);
      expect(report.toString(), contains('Demo Builder'));
      expect(report.toString(), contains('pairedNow=true'));
    });

    test('a failed report explains the fallback instead of throwing', () {
      const report = DevBypassReport.failed('backend unreachable');
      expect(DevBypassConfig.reportIsReady(report), isFalse);
      expect(report.toString(), contains('FAILED'));
      expect(report.toString(), contains('connect and login screens'));
    });
  });

  group('pairing challenge parsing', () {
    test('reads the fields the app needs', () {
      final challenge = PairingChallenge.decode('''
{
  "pairingCode": "482913",
  "serverOrigin": "http://192.168.1.20:8080",
  "apiBaseUrl": "http://192.168.1.20:8080/api/v1",
  "wsBaseUrl": "ws://192.168.1.20:8080/ws"
}
''');
      expect(challenge.pairingCode, '482913');
      expect(challenge.apiBaseUrl, endsWith('/api/v1'));
      expect(challenge.wsBaseUrl, startsWith('ws://'));
    });

    test('tolerates missing optional fields rather than throwing', () {
      final challenge = PairingChallenge.decode('{"pairingCode":"111111"}');
      expect(challenge.pairingCode, '111111');
      expect(challenge.apiBaseUrl, '');
    });

    test('round-trips through json', () {
      const original = PairingChallenge(
        pairingCode: '999888',
        serverOrigin: 'http://host:8080',
        apiBaseUrl: 'http://host:8080/api/v1',
        wsBaseUrl: 'ws://host:8080/ws',
      );
      final decoded = PairingChallenge.fromJson(original.toJson());
      expect(decoded.pairingCode, original.pairingCode);
      expect(decoded.serverOrigin, original.serverOrigin);
    });
  });

  group('debug gating', () {
    test('the bypass stays off unless it was compiled in', () {
      // In this test build DEV_BYPASS was not defined, so it must be off even
      // though kDebugMode is true.
      expect(DevSessionBypass.isEnabled, isFalse);
      expect(DevSessionBypass.enableFlagValue, '');
    });

    test('the raw flag is surfaced so a closed gate can be diagnosed', () {
      // Whatever the build passed, the raw string is readable; this is what made
      // the bool.fromEnvironment failure visible in the first place.
      expect(DevSessionBypass.enableFlagValue, isA<String>());
      expect(
        DevSessionBypass.enableFlagValue.toLowerCase(),
        anyOf('true', ''),
      );
    });

    test('the storage keys it relies on are the ones the repository reads', () {
      expect(DevBypassStorageKeys.apiBaseUrl, 'server.api_base_url');
      expect(
        DevBypassStorageKeys.currentConnectionId,
        'server.current_connection_id',
      );
    });
  });
}
