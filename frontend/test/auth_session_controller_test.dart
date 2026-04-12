import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:microflow_frontend/core/providers/app_providers.dart';
import 'package:microflow_frontend/features/auth/domain/entities/auth_session.dart';
import 'package:microflow_frontend/features/auth/domain/repositories/auth_repository.dart';
import 'package:microflow_frontend/features/auth/presentation/providers/auth_session_controller.dart';

void main() {
  test('signIn restores previous auth state after a failed login', () async {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          _FakeAuthRepository(
            currentSessionValue: null,
            loginError: StateError('login failed'),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(authSessionControllerProvider.future);

    await expectLater(
      container
          .read(authSessionControllerProvider.notifier)
          .signIn(email: 'demo@microflow.local', password: 'wrong'),
      throwsStateError,
    );

    final state = container.read(authSessionControllerProvider);
    expect(state.isLoading, isFalse);
    expect(state.hasError, isFalse);
    expect(state.valueOrNull, isNull);
  });
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({required this.currentSessionValue, this.loginError});

  final AuthSession? currentSessionValue;
  final Object? loginError;

  @override
  Future<AuthSession?> currentSession() async => currentSessionValue;

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    if (loginError != null) {
      throw loginError!;
    }
    throw StateError('Missing fake login result');
  }

  @override
  Future<void> signOut() async {}
}
