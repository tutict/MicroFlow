import 'dart:convert';

final class PairingQrPayload {
  const PairingQrPayload({
    required this.instanceName,
    required this.pairingCode,
    required this.serverOrigin,
    required this.expiresAt,
  });

  final String instanceName;
  final String pairingCode;
  final String serverOrigin;
  final DateTime expiresAt;

  static PairingQrPayload parse(String rawValue, {DateTime? now}) {
    final Object? decoded;
    try {
      decoded = jsonDecode(rawValue);
    } on FormatException {
      throw const FormatException('Invalid pairing QR code');
    }
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Invalid pairing QR code');
    }

    final version = decoded['version'];
    if (version != null && version != 1) {
      throw const FormatException('Unsupported pairing QR version');
    }

    final instanceName = _requiredString(decoded, 'instanceName');
    final rawCode = _requiredString(
      decoded,
      'pairingCode',
    ).replaceAll(' ', '').toUpperCase();
    final pairingCode = rawCode.contains('-')
        ? rawCode
        : rawCode.length == 8
        ? '${rawCode.substring(0, 4)}-${rawCode.substring(4)}'
        : rawCode;
    if (!RegExp(
      r'^[A-HJ-NP-Z2-9]{4}-[A-HJ-NP-Z2-9]{4}$',
    ).hasMatch(pairingCode)) {
      throw const FormatException('Invalid pairing code');
    }

    final serverOrigin = _normalizeOrigin(
      _requiredString(decoded, 'serverOrigin'),
    );
    final expiresAt = DateTime.tryParse(_requiredString(decoded, 'expiresAt'));
    if (expiresAt == null) {
      throw const FormatException('Invalid pairing expiry');
    }
    final effectiveNow = (now ?? DateTime.now()).toUtc();
    if (!expiresAt.toUtc().isAfter(effectiveNow)) {
      throw const FormatException('Pairing code expired');
    }
    if (instanceName.length > 120) {
      throw const FormatException('Invalid instance name');
    }

    return PairingQrPayload(
      instanceName: instanceName,
      pairingCode: pairingCode,
      serverOrigin: serverOrigin,
      expiresAt: expiresAt,
    );
  }

  static String _requiredString(Map<String, Object?> payload, String key) {
    final value = payload[key];
    if (value is! String || value.trim().isEmpty) {
      throw const FormatException('Invalid pairing QR code');
    }
    return value.trim();
  }

  static String _normalizeOrigin(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        uri.query.isNotEmpty ||
        uri.fragment.isNotEmpty) {
      throw const FormatException('Invalid server address');
    }
    final normalized = uri.replace(path: '').toString();
    return normalized.endsWith('/')
        ? normalized.substring(0, normalized.length - 1)
        : normalized;
  }
}
