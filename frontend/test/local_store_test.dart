import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microflow_frontend/core/storage/local_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final values = <String, String>{};
  final calls = <MethodCall>[];
  var writeFails = false;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    values.clear();
    calls.clear();
    writeFails = false;
    SharedPreferences.setMockInitialValues({});
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call);
      final arguments = Map<String, dynamic>.from(call.arguments as Map);
      final key = arguments['key'] as String;
      switch (call.method) {
        case 'read':
          return values[key];
        case 'write':
          if (writeFails) {
            throw PlatformException(code: 'StorageError');
          }
          values[key] = arguments['value'] as String;
        case 'delete':
          values.remove(key);
        default:
          throw StateError('Unexpected storage operation: ${call.method}');
      }
      return null;
    });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test(
    'existing keys use backed-up migration without automatic data reset',
    () async {
      values['jwt_token'] = 'existing-token';

      expect(await LocalStore().readString('jwt_token'), 'existing-token');

      final arguments = Map<String, dynamic>.from(
        calls.single.arguments as Map,
      );
      final options = Map<String, String>.from(arguments['options'] as Map);
      expect(options['resetOnError'], 'false');
      expect(options['migrateOnAlgorithmChange'], 'true');
      expect(options['migrateWithBackup'], 'true');
      expect(arguments['key'], 'jwt_token');
    },
  );

  test('failed preference migration retains data and can be retried', () async {
    SharedPreferences.setMockInitialValues({'jwt_token': 'legacy-token'});
    final store = LocalStore();
    writeFails = true;

    await expectLater(
      store.migrateFromPreferences(['jwt_token']),
      throwsA(isA<PlatformException>()),
    );
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('jwt_token'), 'legacy-token');
    expect(values, isEmpty);

    writeFails = false;
    await store.migrateFromPreferences(['jwt_token']);
    expect(await store.readString('jwt_token'), 'legacy-token');
    expect(preferences.containsKey('jwt_token'), isFalse);
  });

  test('secure values can be written, read, and removed', () async {
    final store = LocalStore();
    await store.saveString('connection_catalog', 'saved-connections');
    expect(await store.readString('connection_catalog'), 'saved-connections');
    await store.remove('connection_catalog');
    expect(await store.readString('connection_catalog'), isNull);
  });
}
