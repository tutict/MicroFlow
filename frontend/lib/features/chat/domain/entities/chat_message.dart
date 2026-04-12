class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.author,
    required this.text,
    required this.createdAt,
    required this.isAgent,
  });

  final String id;
  final String author;
  final String text;
  final String createdAt;
  final bool isAgent;
}
