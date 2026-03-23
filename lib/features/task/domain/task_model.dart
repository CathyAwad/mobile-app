class TaskModel {
  final String id;
  final String? title;
  final String? status;
  final String? chatId;

  TaskModel({
    required this.id,
    this.title,
    this.status,
    this.chatId,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id'] as String,
      title: json['title'] as String?,
      status: json['status'] as String?,
      chatId: json['chat_id'] as String?,
    );
  }
}
