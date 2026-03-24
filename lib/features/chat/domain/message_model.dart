import 'package:frona_mobile/features/chat/domain/tool_model.dart';

class ChatMessage {
  final String id;
  final String role;
  final String content;
  final String? status;
  final List<ToolExecution> toolExecutions;

  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    this.status,
    this.toolExecutions = const [],
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      role: json['role'] as String,
      content: json['content'] as String,
      status: json['status'] as String?,
      toolExecutions: (json['tool_executions'] as List<dynamic>?)
              ?.map((te) => ToolExecution.fromJson(te as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  ChatMessage copyWith({
    String? id,
    String? content,
    String? status,
    List<ToolExecution>? toolExecutions,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      role: role,
      content: content ?? this.content,
      status: status ?? this.status,
      toolExecutions: toolExecutions ?? this.toolExecutions,
    );
  }
}
