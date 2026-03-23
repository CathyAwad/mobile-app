class Agent {
  final String id;
  final String name;
  final String? description;
  final bool enabled;

  Agent({
    required this.id,
    required this.name,
    this.description,
    required this.enabled,
  });

  factory Agent.fromJson(Map<String, dynamic> json) {
    return Agent(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      enabled: json['enabled'] as bool? ?? true,
    );
  }
}
