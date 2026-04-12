import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/rest_client.dart';
import '../dto/message_dto.dart';
import '../dto/send_message_request_dto.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/repositories/chat_repository.dart';

class ChatRepositoryImpl implements ChatRepository {
  const ChatRepositoryImpl(this._restClient);

  final RestClient _restClient;

  @override
  Future<List<ChatMessage>> listMessages(String channelId) async {
    final response = await _restClient.getJsonList(ApiEndpoints.channelMessages(channelId));
    return response.map((json) => MessageDto.fromJson(json).toDomain()).toList();
  }

  @override
  Future<ChatMessage> sendMessage({
    required String workspaceId,
    required String channelId,
    required String senderUserId,
    required String content,
  }) async {
    final request = SendMessageRequestDto(
      workspaceId: workspaceId,
      content: content,
    );
    final response = await _restClient.postJson(
      ApiEndpoints.channelMessages(channelId),
      body: request.toJson(),
    );
    return MessageDto.fromJson(response).toDomain();
  }
}
