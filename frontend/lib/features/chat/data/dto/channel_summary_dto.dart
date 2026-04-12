import '../../domain/entities/channel_summary.dart';

class ChannelSummaryDto {
  const ChannelSummaryDto({
    required this.id,
    required this.name,
    required this.unreadCount,
  });

  final String id;
  final String name;
  final int unreadCount;

  factory ChannelSummaryDto.fromJson(Map<String, Object?> json) {
    return ChannelSummaryDto(
      id: json['id'] as String,
      name: json['name'] as String,
      unreadCount: json['unreadCount'] as int,
    );
  }

  ChannelSummary toDomain() {
    return ChannelSummary(
      id: id,
      name: name,
      unreadCount: unreadCount,
    );
  }
}
