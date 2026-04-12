import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class LocalStore {
  LocalStore({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? _defaultSecureStorage;

  static const FlutterSecureStorage _defaultSecureStorage =
      FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
      );

  final FlutterSecureStorage _secureStorage;

  static Future<SharedPreferences> get _preferences async {
    return SharedPreferences.getInstance();
  }

  Future<void> saveString(String key, String value) async {
    await _secureStorage.write(key: key, value: value);
  }

  Future<String?> readString(String key) async {
    return _secureStorage.read(key: key);
  }

  Future<void> remove(String key) async {
    await _secureStorage.delete(key: key);
  }

  Future<void> migrateFromPreferences(Iterable<String> keys) async {
    final preferences = await _preferences;
    for (final key in keys) {
      final value = preferences.getString(key);
      if (value == null) {
        continue;
      }
      await _secureStorage.write(key: key, value: value);
      await preferences.remove(key);
    }
  }
}
