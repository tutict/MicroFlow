import '../../../../core/storage/local_store.dart';
import '../../../../core/network/rest_client.dart';
import '../dto/auth_tokens_dto.dart';
import '../dto/login_request_dto.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl(this._restClient, this._localStore);

  final RestClient _restClient;
  final LocalStore _localStore;

  static const _accessTokenKey = 'auth.access_token';
  static const _refreshTokenKey = 'auth.refresh_token';
  static const _userIdKey = 'auth.user_id';
  static const _emailKey = 'auth.email';
  static const _displayNameKey = 'auth.display_name';
  static const _secureKeys = <String>[
    _accessTokenKey,
    _refreshTokenKey,
    _userIdKey,
    _emailKey,
    _displayNameKey,
  ];

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final dto = LoginRequestDto(email: email, password: password);
    final response = await _restClient.postJson(
      '/auth/login',
      authenticated: false,
      body: dto.toJson(),
    );
    final tokens = AuthTokensDto.fromJson({
      ...response,
      'email': email,
    }).toDomain();
    await _persist(tokens);
    return tokens;
  }

  @override
  Future<AuthSession?> currentSession() async {
    await _localStore.migrateFromPreferences(_secureKeys);
    final accessToken = await _localStore.readString(_accessTokenKey);
    final refreshToken = await _localStore.readString(_refreshTokenKey);
    final userId = await _localStore.readString(_userIdKey);
    final email = await _localStore.readString(_emailKey);
    final displayName = await _localStore.readString(_displayNameKey);
    if (accessToken == null ||
        refreshToken == null ||
        userId == null ||
        email == null ||
        displayName == null) {
      return null;
    }
    return AuthSession(
      userId: userId,
      email: email,
      displayName: displayName,
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
  }

  @override
  Future<void> signOut() async {
    await _localStore.remove(_accessTokenKey);
    await _localStore.remove(_refreshTokenKey);
    await _localStore.remove(_userIdKey);
    await _localStore.remove(_emailKey);
    await _localStore.remove(_displayNameKey);
  }

  Future<void> _persist(AuthSession session) async {
    await _localStore.saveString(_accessTokenKey, session.accessToken);
    await _localStore.saveString(_refreshTokenKey, session.refreshToken);
    await _localStore.saveString(_userIdKey, session.userId);
    await _localStore.saveString(_emailKey, session.email);
    await _localStore.saveString(_displayNameKey, session.displayName);
  }
}
