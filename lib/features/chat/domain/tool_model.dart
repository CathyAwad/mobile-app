enum ToolStatus {
  pending,
  resolved,
  denied;

  static ToolStatus fromJson(String json) {
    return ToolStatus.values.firstWhere(
      (e) => e.name == json.toLowerCase(),
      orElse: () => ToolStatus.pending,
    );
  }
}

abstract class MessageTool {
  final ToolStatus status;
  final String? response;

  MessageTool({required this.status, this.response});

  factory MessageTool.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    final data = json['data'] as Map<String, dynamic>;
    final status = ToolStatus.fromJson(data['status'] as String);
    final response = data['response'] as String?;

    switch (type.toLowerCase()) {
      case 'vaultapproval':
        return VaultApprovalTool(
          status: status,
          response: response,
          query: data['query'] as String,
          reason: data['reason'] as String,
          envVarPrefix: data['env_var_prefix'] as String?,
        );
      case 'humanintheloop':
      case 'question':
      case 'taskcompletion':
      case 'taskdeferred':
      case 'serviceapproval':
      default:
        return GenericMessageTool(status: status, response: response, type: type, data: data);
    }
  }

  Map<String, dynamic> toJson();
}

class VaultApprovalTool extends MessageTool {
  final String query;
  final String reason;
  final String? envVarPrefix;

  VaultApprovalTool({
    required super.status,
    super.response,
    required this.query,
    required this.reason,
    this.envVarPrefix,
  });

  @override
  Map<String, dynamic> toJson() => {
    'type': 'vaultapproval',
    'data': {
      'query': query,
      'reason': reason,
      'env_var_prefix': envVarPrefix,
      'status': status.name,
      'response': response,
    },
  };
}

class GenericMessageTool extends MessageTool {
  final String type;
  final Map<String, dynamic> data;

  GenericMessageTool({
    required super.status,
    super.response,
    required this.type,
    required this.data,
  });

  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    'data': data,
  };
}

class ToolExecution {
  final String id;
  final String chatId;
  final String messageId;
  final int turn;
  final String toolCallId;
  final String name;
  final dynamic arguments;
  final String result;
  final bool success;
  final int durationMs;
  final MessageTool? toolData;
  final String? turnText;
  final String? systemPrompt;
  final DateTime createdAt;

  ToolExecution({
    required this.id,
    required this.chatId,
    required this.messageId,
    required this.turn,
    required this.toolCallId,
    required this.name,
    required this.arguments,
    required this.result,
    required this.success,
    required this.durationMs,
    this.toolData,
    this.turnText,
    this.systemPrompt,
    required this.createdAt,
  });

  factory ToolExecution.fromJson(Map<String, dynamic> json) {
    return ToolExecution(
      id: json['id'] as String,
      chatId: json['chat_id'] as String,
      messageId: json['message_id'] as String,
      turn: json['turn'] as int,
      toolCallId: json['tool_call_id'] as String,
      name: json['name'] as String,
      arguments: json['arguments'],
      result: json['result'] as String,
      success: json['success'] as bool,
      durationMs: json['duration_ms'] as int,
      toolData: json['tool_data'] != null ? MessageTool.fromJson(json['tool_data']) : null,
      turnText: json['turn_text'] as String?,
      systemPrompt: json['system_prompt'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  ToolExecution copyWith({
    String? result,
    bool? success,
    MessageTool? toolData,
  }) {
    return ToolExecution(
      id: id,
      chatId: chatId,
      messageId: messageId,
      turn: turn,
      toolCallId: toolCallId,
      name: name,
      arguments: arguments,
      result: result ?? this.result,
      success: success ?? this.success,
      durationMs: durationMs,
      toolData: toolData ?? this.toolData,
      turnText: turnText,
      systemPrompt: systemPrompt,
      createdAt: createdAt,
    );
  }
}
