class ChatMessage {
  final String id;
  final String role;
  final String content;

  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      role: json['role'] as String,
      content: json['content'] as String,
    );
  }
}
