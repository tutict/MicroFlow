import '../../domain/entities/auth_session.dart';

class AuthTokensDto {
  const AuthTokensDto({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    required this.email,
    required this.displayName,
  });

  final String accessToken;
  final String refreshToken;
  final String userId;
  final String email;
  final String displayName;

  factory AuthTokensDto.fromJson(Map<String, Object?> json) {
    return AuthTokensDto(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      userId: json['userId'] as String,
      email: (json['email'] as String?) ?? '',
      displayName: json['displayName'] as String,
    );
  }

  AuthSession toDomain() {
    return AuthSession(
      userId: userId,
      email: email,
      displayName: displayName,
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
  }
}
