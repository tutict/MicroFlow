import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config/app_environment.dart';
import '../config/server_connection_keys.dart';
import '../errors/app_exception.dart';
import '../storage/local_store.dart';

final class RestClient {
  const RestClient(this._localStore);

  final LocalStore _localStore;

  static const _accessTokenKey = 'auth.access_token';
  static const _requestTimeout = Duration(seconds: 15);
  static const _multipartTimeout = Duration(seconds: 60);

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
    final response = await _send(
      () async => http.get(
        await buildUrl(path, queryParameters),
        headers: await _headers(authenticated: authenticated),
      ),
    );
    return _decodeMap(response);
  }

  Future<List<Map<String, Object?>>> getJsonList(
    String path, {
    Map<String, String>? queryParameters,
    bool authenticated = true,
  }) async {
    final response = await _send(
      () async => http.get(
        await buildUrl(path, queryParameters),
        headers: await _headers(authenticated: authenticated),
      ),
    );
    return _decodeList(response);
  }

  Future<Map<String, Object?>> postJson(
    String path, {
    required Map<String, Object?> body,
    bool authenticated = true,
  }) async {
    final response = await _send(
      () async => http.post(
        await buildUrl(path),
        headers: await _headers(authenticated: authenticated),
        body: jsonEncode(body),
      ),
    );
    return _decodeMap(response);
  }

  Future<List<Map<String, Object?>>> postJsonList(
    String path, {
    required Map<String, Object?> body,
    bool authenticated = true,
  }) async {
    final response = await _send(
      () async => http.post(
        await buildUrl(path),
        headers: await _headers(authenticated: authenticated),
        body: jsonEncode(body),
      ),
    );
    return _decodeList(response);
  }

  Future<Map<String, Object?>> putJson(
    String path, {
    required Map<String, Object?> body,
    Map<String, String>? queryParameters,
    bool authenticated = true,
  }) async {
    final response = await _send(
      () async => http.put(
        await buildUrl(path, queryParameters),
        headers: await _headers(authenticated: authenticated),
        body: jsonEncode(body),
      ),
    );
    return _decodeMap(response);
  }

  Future<Map<String, Object?>> postMultipart(
    String path, {
    required String fileField,
    required String fileName,
    required Uint8List fileBytes,
    Map<String, String>? fields,
    bool authenticated = true,
  }) async {
    final request = http.MultipartRequest('POST', await buildUrl(path));
    request.headers.addAll(
      await _headers(authenticated: authenticated, json: false),
    );
    if (fields != null) {
      request.fields.addAll(fields);
    }
    request.files.add(
      http.MultipartFile.fromBytes(fileField, fileBytes, filename: fileName),
    );
    final response = await _send(() async {
      final streamed = await request.send().timeout(_multipartTimeout);
      return http.Response.fromStream(streamed).timeout(_requestTimeout);
    }, timeout: _multipartTimeout);
    return _decodeMap(response);
  }

  Future<Map<String, String>> _headers({
    required bool authenticated,
    bool json = true,
  }) async {
    final headers = <String, String>{'Accept': 'application/json'};
    if (json) {
      headers['Content-Type'] = 'application/json';
    }
    if (authenticated) {
      final token = await _localStore.readString(_accessTokenKey);
      if (token == null || token.isEmpty) {
        throw const AppException('Missing access token');
      }
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<http.Response> _send(
    Future<http.Response> Function() request, {
    Duration timeout = _requestTimeout,
  }) async {
    try {
      return await request().timeout(timeout);
    } on TimeoutException {
      throw const AppException('Request timed out');
    } on http.ClientException catch (error) {
      throw AppException('Network request failed: ${error.message}');
    } on FormatException {
      rethrow;
    } catch (error) {
      throw AppException('Network request failed: $error');
    }
  }

  Map<String, Object?> _decodeMap(http.Response response) {
    final payload = _decodePayload(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AppException(_errorMessage(response, payload));
    }
    if (payload is! Map<String, Object?>) {
      throw const AppException('Expected JSON object');
    }
    return payload;
  }

  List<Map<String, Object?>> _decodeList(http.Response response) {
    final payload = _decodePayload(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AppException(_errorMessage(response, payload));
    }
    if (payload is! List) {
      throw const AppException('Expected JSON list');
    }
    return payload
        .cast<Map>()
        .map((entry) => entry.cast<String, Object?>())
        .toList();
  }

  Object? _decodePayload(http.Response response) {
    if (response.body.isEmpty) {
      return response.statusCode >= 200 && response.statusCode < 300
          ? const <String, Object?>{}
          : null;
    }
    try {
      return jsonDecode(response.body);
    } on FormatException {
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      throw const AppException('Invalid JSON response');
    }
  }

  String _errorMessage(http.Response response, Object? payload) {
    if (payload is Map<String, Object?>) {
      final message = payload['message'];
      if (message is String && message.isNotEmpty) {
        return message;
      }
    }
    return 'Request failed with status ${response.statusCode}';
  }
}
