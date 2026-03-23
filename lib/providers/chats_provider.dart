
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../core/api/api_client.dart';
import '../features/chat/domain/chat_model.dart';
import '../features/chat/domain/message_model.dart';
import 'spaces_provider.dart';

final chatsProvider = FutureProvider<List<Chat>>((ref) async {
  final nav = await ref.watch(navigationProvider.future);
  return nav.standaloneChats;
});

final chatProvider = FutureProvider.family<Chat, String>((ref, chatId) async {
  final nav = await ref.watch(navigationProvider.future);
  // Search in standalone
  final standalone = nav.standaloneChats.where((c) => c.id == chatId);
  if (standalone.isNotEmpty) return standalone.first;
  
  // Search in spaces
  for (final space in nav.spaces) {
    if (space.chats != null) {
      final found = space.chats!.where((c) => c.id == chatId);
      if (found.isNotEmpty) return found.first;
    }
  }
  
  // Fallback to fetching directly if not in navigation (e.g. archived or task chat)
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/chats/$chatId');
  return Chat.fromJson(response.data);
});

final chatMessagesProvider = FutureProvider.family<List<ChatMessage>, String>((ref, chatId) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/chats/$chatId/messages');
  
  final List<dynamic> data = response.data;
  return data.map((json) => ChatMessage.fromJson(json)).toList();
});

final sendMessageProvider = Provider<void Function(String, String)>((ref) {
  return (chatId, content) async {
    final dio = ref.read(dioProvider);
    await dio.post('/chats/$chatId/messages', data: {'content': content});
    // Invalidate the message list so it refreshes
    ref.invalidate(chatMessagesProvider(chatId));
  };
});

final archivedChatsProvider = FutureProvider<List<Chat>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/chats/archived');
  
  final List<dynamic> data = response.data;
  return data
      .map((json) => Chat.fromJson(json))
      .toList();
});

final createChatProvider = Provider<Future<Chat> Function({String? spaceId, String? agentId})>((ref) {
  return ({spaceId, agentId}) async {
    final dio = ref.read(dioProvider);
    String targetAgentId = agentId ?? '';
    
    if (targetAgentId.isEmpty) {
      final agentsResponse = await dio.get('/agents');
      final agentsList = agentsResponse.data as List;
      if (agentsList.isNotEmpty) {
        targetAgentId = agentsList.first['id'] as String;
      }
    }
    
    final payload = <String, dynamic>{
      'agent_id': targetAgentId,
    };
    if (spaceId != null) {
      payload['space_id'] = spaceId;
    }
    
    final response = await dio.post('/chats', data: payload);
    ref.invalidate(chatsProvider);
    ref.invalidate(navigationProvider);
    return Chat.fromJson(response.data);
  };
});

final archiveChatProvider = Provider<Future<void> Function(String)>((ref) {
  return (chatId) async {
    final dio = ref.read(dioProvider);
    await dio.post('/chats/$chatId/archive');
    ref.invalidate(chatsProvider);
    ref.invalidate(archivedChatsProvider);
    ref.invalidate(navigationProvider);
  };
});

final unarchiveChatProvider = Provider<Future<void> Function(String)>((ref) {
  return (chatId) async {
    final dio = ref.read(dioProvider);
    await dio.post('/chats/$chatId/unarchive');
    ref.invalidate(chatsProvider);
    ref.invalidate(archivedChatsProvider);
    ref.invalidate(navigationProvider);
  };
});

final deleteChatProvider = Provider<Future<void> Function(String)>((ref) {
  return (chatId) async {
    final dio = ref.read(dioProvider);
    await dio.delete('/chats/$chatId');
    ref.invalidate(chatsProvider);
    ref.invalidate(archivedChatsProvider);
    ref.invalidate(navigationProvider);
  };
});
