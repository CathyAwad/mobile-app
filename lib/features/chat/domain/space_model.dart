import 'chat_model.dart';

class SpaceModel {
  final String id;
  final String name;
  final List<Chat>? chats;

  SpaceModel({
    required this.id,
    required this.name,
    this.chats,
  });

  factory SpaceModel.fromJson(Map<String, dynamic> json) {
    return SpaceModel(
      id: json['id'] as String,
      name: json['name'] as String,
      chats: (json['chats'] as List<dynamic>?)
          ?.map((e) => Chat.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class NavigationModel {
  final List<SpaceModel> spaces;
  final List<Chat> standaloneChats;

  NavigationModel({
    required this.spaces,
    required this.standaloneChats,
  });

  factory NavigationModel.fromJson(Map<String, dynamic> json) {
    return NavigationModel(
      spaces: (json['spaces'] as List<dynamic>)
          .map((e) => SpaceModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      standaloneChats: (json['standalone_chats'] as List<dynamic>)
          .map((e) => Chat.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
