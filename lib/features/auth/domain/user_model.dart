class User {
  final String id;
  final String username;
  final String email;
  final String name;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.name,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      username: json['username'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
    );
  }
}
