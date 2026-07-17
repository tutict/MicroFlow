import 'package:flutter_test/flutter_test.dart';
import 'package:microflow_frontend/features/bootstrap/domain/entities/pairing_qr_payload.dart';

void main() {
  final now = DateTime.parse('2026-07-17T00:00:00Z');

  test('parses the backend pairing payload', () {
    final payload = PairingQrPayload.parse('''
      {
        "instanceName": "Office PC",
        "pairingCode": "ABCD-7KQ2",
        "serverOrigin": "http://192.168.1.20:8080",
        "apiBaseUrl": "http://192.168.1.20:8080/api/v1",
        "wsBaseUrl": "ws://192.168.1.20:8080/ws",
        "expiresAt": "2026-07-17T00:10:00Z"
      }
      ''', now: now);

    expect(payload.instanceName, 'Office PC');
    expect(payload.pairingCode, 'ABCD-7KQ2');
    expect(payload.serverOrigin, 'http://192.168.1.20:8080');
  });

  test('normalizes an unseparated pairing code', () {
    final payload = PairingQrPayload.parse('''
      {
        "instanceName": "Office PC",
        "pairingCode": "ABCD7KQ2",
        "serverOrigin": "https://device.example.test/",
        "expiresAt": "2026-07-17T00:10:00Z"
      }
      ''', now: now);

    expect(payload.pairingCode, 'ABCD-7KQ2');
    expect(payload.serverOrigin, 'https://device.example.test');
  });

  test('rejects expired codes', () {
    expect(
      () => PairingQrPayload.parse('''
        {
          "instanceName": "Office PC",
          "pairingCode": "ABCD-7KQ2",
          "serverOrigin": "http://192.168.1.20:8080",
          "expiresAt": "2026-07-16T23:59:59Z"
        }
        ''', now: now),
      throwsFormatException,
    );
  });

  test('rejects non-http server origins', () {
    expect(
      () => PairingQrPayload.parse('''
        {
          "instanceName": "Office PC",
          "pairingCode": "ABCD-7KQ2",
          "serverOrigin": "file:///tmp/microflow",
          "expiresAt": "2026-07-17T00:10:00Z"
        }
        ''', now: now),
      throwsFormatException,
    );
  });

  test('rejects credentials embedded in the server origin', () {
    expect(
      () => PairingQrPayload.parse('''
        {
          "instanceName": "Office PC",
          "pairingCode": "ABCD-7KQ2",
          "serverOrigin": "http://user:pass@192.168.1.20:8080",
          "expiresAt": "2026-07-17T00:10:00Z"
        }
        ''', now: now),
      throwsFormatException,
    );
  });

  test('rejects a server origin containing an unexpected path', () {
    expect(
      () => PairingQrPayload.parse('''
        {
          "instanceName": "Office PC",
          "pairingCode": "ABCD-7KQ2",
          "serverOrigin": "http://192.168.1.20:8080/untrusted",
          "expiresAt": "2026-07-17T00:10:00Z"
        }
        ''', now: now),
      throwsFormatException,
    );
  });
}
