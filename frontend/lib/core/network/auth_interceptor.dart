typedef HeaderMap = Map<String, String>;

final class AuthInterceptor {
  const AuthInterceptor();

  HeaderMap apply(HeaderMap headers, {String? token}) {
    if (token == null || token.isEmpty) {
      return headers;
    }
    return <String, String>{
      ...headers,
      'Authorization': 'Bearer $token',
    };
  }
}
