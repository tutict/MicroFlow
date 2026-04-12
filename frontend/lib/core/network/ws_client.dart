import '../config/app_environment.dart';
import '../config/server_connection_keys.dart';
import '../errors/app_exception.dart';
import '../storage/local_store.dart';

final class WsClient {
  const WsClient(this._localStore);

  final LocalStore _localStore;

  Future<Uri> endpoint({String? ticket}) async {
    final baseUrl =
        await _localStore.readString(ServerConnectionKeys.wsBaseUrl) ??
        AppEnvironment.wsBaseUrl;
    if (baseUrl.isEmpty) {
      throw const AppException('No server connection configured');
    }
    final uri = Uri.parse(baseUrl);
    if (ticket == null || ticket.isEmpty) {
      return uri;
    }
    return uri.replace(
      queryParameters: {...uri.queryParameters, 'ticket': ticket},
    );
  }
}
