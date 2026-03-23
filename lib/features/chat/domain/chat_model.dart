class Chat {
  final String id;
  final String? title;
  final String agentId;
  final String? spaceId;
  final String? taskId;
  final String? archivedAt;

  Chat({
    required this.id,
    this.title,
    required this.agentId,
    this.spaceId,
    this.taskId,
    this.archivedAt,
  });

  factory Chat.fromJson(Map<String, dynamic> json) {
    return Chat(
      id: json['id'] as String,
      title: json['title'] as String?,
      agentId: json['agent_id'] as String,
      spaceId: json['space_id'] as String?,
      taskId: json['task_id'] as String?,
      archivedAt: json['archived_at'] as String?,
    );
  }
}
