class ChannelSummary {
  const ChannelSummary({
    required this.id,
    required this.name,
    required this.unreadCount,
  });

  final String id;
  final String name;
  final int unreadCount;
}
