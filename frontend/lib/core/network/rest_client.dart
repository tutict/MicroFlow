import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_environment.dart';
import '../config/server_connection_keys.dart';
import '../errors/app_exception.dart';
import '../storage/local_store.dart';

final class RestClient {
  const RestClient(this._localStore);

  final LocalStore _localStore;

  static const _accessTokenKey = 'auth.access_token';

  Future<Uri> buildUrl(
    String path, [
    Map<String, String>? queryParameters,
  ]) async {
    final baseUrl =
        await _localStore.readString(ServerConnectionKeys.apiBaseUrl) ??
        AppEnvironment.apiBaseUrl;
    if (baseUrl.isEmpty) {
      throw const AppException('No server connection configured');
    }
    return Uri.parse('$baseUrl$path').replace(queryParameters: queryParameters);
  }

  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, String>? queryParameters,
    bool authenticated = true,
  }) async {
    final response = await http.get(
      await buildUrl(path, queryParameters),
      headers: await _headers(authenticated: authenticated),
    );
    return _decodeMap(response);
  }

  Future<List<Map<String, Object?>>> getJsonList(
    String path, {
    Map<String, String>? queryParameters,
    bool authenticated = true,
  }) async {
    final response = await http.get(
      await buildUrl(path, queryParameters),
      headers: await _headers(authenticated: authenticated),
    );
    return _decodeList(response);
  }

  Future<Map<String, Object?>> postJson(
    String path, {
    required Map<String, Object?> body,
    bool authenticated = true,
  }) async {
    final response = await http.post(
      await buildUrl(path),
      headers: await _headers(authenticated: authenticated),
      body: jsonEncode(body),
    );
    return _decodeMap(response);
  }

  Future<Map<String, Object?>> putJson(
    String path, {
    required Map<String, Object?> body,
    Map<String, String>? queryParameters,
    bool authenticated = true,
  }) async {
    final response = await http.put(
      await buildUrl(path, queryParameters),
      headers: await _headers(authenticated: authenticated),
      body: jsonEncode(body),
    );
    return _decodeMap(response);
  }

  Future<Map<String, String>> _headers({required bool authenticated}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (authenticated) {
      final token = await _localStore.readString(_accessTokenKey);
      if (token == null || token.isEmpty) {
        throw const AppException('Missing access token');
      }
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Map<String, Object?> _decodeMap(http.Response response) {
    final payload = response.body.isEmpty
        ? const <String, Object?>{}
        : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = payload is Map<String, Object?>
          ? (payload['message'] as String?)
          : null;
      throw AppException(
        message ?? 'Request failed with status ${response.statusCode}',
      );
    }
    if (payload is! Map<String, Object?>) {
      throw const AppException('Expected JSON object');
    }
    return payload;
  }

  List<Map<String, Object?>> _decodeList(http.Response response) {
    final payload = response.body.isEmpty
        ? const []
        : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String? message;
      if (payload is Map<String, Object?>) {
        message = payload['message'] as String?;
      }
      throw AppException(
        message ?? 'Request failed with status ${response.statusCode}',
      );
    }
    if (payload is! List) {
      throw const AppException('Expected JSON list');
    }
    return payload
        .cast<Map>()
        .map((entry) => entry.cast<String, Object?>())
        .toList();
  }
}
