import 'package:frona_mobile/features/chat/domain/message_model.dart';
import 'package:frona_mobile/features/chat/domain/tool_model.dart';

class ChatEvent {
  final String type;
  final String? chatId;
  final String? content;
  final ChatMessage? message;
  final ToolExecution? toolExecution;

  ChatEvent({
    required this.type,
    this.chatId,
    this.content,
    this.message,
    this.toolExecution,
  });

  factory ChatEvent.fromJson(String type, Map<String, dynamic> json) {
    return ChatEvent(
      type: type,
      chatId: json['chat_id'] as String?,
      content: json['content'] as String?,
      message: json['message'] != null
          ? ChatMessage.fromJson(json['message'] as Map<String, dynamic>)
          : null,
      toolExecution: json['tool_execution'] != null
          ? ToolExecution.fromJson(json['tool_execution'] as Map<String, dynamic>)
          : null,
    );
  }
}
