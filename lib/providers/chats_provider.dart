import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:frona_mobile/core/api/api_client.dart';
import 'package:frona_mobile/features/chat/domain/chat_model.dart';
import 'package:frona_mobile/features/chat/domain/chat_event.dart';
import 'package:frona_mobile/features/chat/domain/message_model.dart';
import 'package:frona_mobile/features/chat/domain/tool_model.dart';
import 'package:frona_mobile/features/chat/providers/chat_stream_provider.dart';
import 'package:frona_mobile/providers/spaces_provider.dart';

final chatsProvider = FutureProvider<List<Chat>>((ref) async {
  final nav = await ref.watch(navigationProvider.future);
  return nav.standaloneChats;
});

final chatProvider = FutureProvider.family<Chat, String>((ref, chatId) async {
  if (chatId.startsWith('new:')) {
    final parts = chatId.split(':');
    final agentId = parts.length > 1 && parts[1] != 'default' ? parts[1] : 'default';
    return Chat(id: chatId, agentId: agentId, title: 'New chat');
  }

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

class ChatController extends ValueNotifier<AsyncValue<List<ChatMessage>>> {
  final Ref ref;
  final String chatId;
  StreamSubscription<ChatEvent>? _subscription;

  ChatController(this.ref, this.chatId) : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    if (chatId.startsWith('new:')) {
      value = const AsyncValue.data([]);
      return;
    }
    
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get('/chats/$chatId/messages');
      final List<dynamic> data = response.data;
      List<ChatMessage> messages = data.map((json) => ChatMessage.fromJson(json)).toList();

      value = AsyncValue.data(messages);

      // Setup SSE listener
      final stream = ref.read(chatStreamProvider);
      _subscription = stream.listen((event) {
        if (event.chatId != chatId) return;
        _handleEvent(event);
      });
    } catch (e, st) {
      value = AsyncValue.error(e, st);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _handleEvent(ChatEvent event) {
    if (!value.hasValue || value.value == null) return;
    final messages = List<ChatMessage>.from(value.value!);
    bool changed = false;

    switch (event.type) {
      case 'token':
        if (messages.isNotEmpty && messages.last.role == 'agent' && (messages.last.status == 'executing' || messages.last.status == null)) {
          messages[messages.length - 1] = messages.last.copyWith(
            content: messages.last.content + (event.content ?? ''),
            status: 'executing',
          );
          changed = true;
        }
        break;
      
      case 'inference_done':
      case 'chat_message':
      case 'tool_resolved':
        final newMessage = event.message;
        if (newMessage != null) {
          final index = messages.indexWhere((m) => m.id == newMessage.id);
          if (index != -1) {
            // Preserve active tool executions if the incoming message doesn't explicitly clear them
            final existingExecs = messages[index].toolExecutions;
            final newExecs = newMessage.toolExecutions;
            final mergedExecs = newExecs.isEmpty && existingExecs.isNotEmpty ? existingExecs : newExecs;
            
            messages[index] = newMessage.copyWith(toolExecutions: mergedExecs);
          } else {
             // Replace temporary user message
             if (newMessage.role == 'user') {
                final lastUser = messages.lastWhere((m) => m.role == 'user', orElse: () => messages.first);
                if (lastUser.status == 'sending' && lastUser.id.startsWith('temp-')) {
                   final uiIndex = messages.indexOf(lastUser);
                   if (uiIndex != -1) {
                      messages[uiIndex] = newMessage;
                   } else {
                      messages.add(newMessage);
                   }
                } else {
                   messages.add(newMessage);
                }
             }
             // Replace temporary agent message
             else if (newMessage.role == 'agent') {
               final last = messages.last;
               if (last.role == 'agent' && (last.status == 'executing' || last.status == null) && last.id.startsWith('temp-')) {
                  // Preserve active tool executions if the incoming message doesn't explicitly clear them
                  final existingExecs = last.toolExecutions;
                  final newExecs = newMessage.toolExecutions;
                  final mergedExecs = newExecs.isEmpty && existingExecs.isNotEmpty ? existingExecs : newExecs;
                  
                  messages[messages.length - 1] = newMessage.copyWith(toolExecutions: mergedExecs);
               } else {
                  messages.add(newMessage);
               }
            } else {
               messages.add(newMessage);
            }
          }
          changed = true;
        }
        break;

      case 'tool_message':
        final te = event.toolExecution;
        if (te != null) {
          int messageIndex = messages.indexWhere((m) => m.id == te.messageId);
          
          if (messageIndex == -1) {
            // Find the last agent message that is still executing and adopt the real messageId
            messageIndex = messages.lastIndexWhere((m) => m.role == 'agent' && (m.status == 'executing' || m.status == null));
            if (messageIndex != -1) {
              messages[messageIndex] = messages[messageIndex].copyWith(id: te.messageId);
            }
          }

          if (messageIndex != -1) {
            final message = messages[messageIndex];
            final toolExecs = List<ToolExecution>.from(message.toolExecutions);
            final teIndex = toolExecs.indexWhere((t) => t.id == te.id);
            if (teIndex != -1) {
              toolExecs[teIndex] = te;
            } else {
              toolExecs.add(te);
            }
            messages[messageIndex] = message.copyWith(toolExecutions: toolExecs);
            changed = true;
          }
        }
        break;
    }

    if (changed) {
      value = AsyncValue.data(messages);
    }
  }

  Future<void> sendMessageOptimistically(String content, String targetChatId) async {
    if (!value.hasValue || value.value == null) return;
    final messages = List<ChatMessage>.from(value.value!);
    
    // Add temporary user message
    messages.add(ChatMessage(
      id: 'temp-user-${DateTime.now().millisecondsSinceEpoch}',
      role: 'user',
      content: content,
      status: 'sending',
      toolExecutions: [],
    ));

    // Add temporary agent loading message
    messages.add(ChatMessage(
      id: 'temp-agent-${DateTime.now().millisecondsSinceEpoch}',
      role: 'agent',
      content: '', // Empty initially
      status: 'executing',
      toolExecutions: [],
    ));

    value = AsyncValue.data(messages);

    // Trigger the actual backend request
    final dio = ref.read(dioProvider);
    try {
      await dio.post('/chats/$targetChatId/messages/stream', data: {'content': content});
    } catch (e) {
      print('Error sending message: $e');
    }
  }

  void resolvePendingTool(String newStatus) {
    if (!value.hasValue || value.value == null) return;
    final messages = List<ChatMessage>.from(value.value!);
    if (messages.isEmpty) return;
    
    // Find the message with the pending tool
    final msgIndex = messages.lastIndexWhere((m) => m.toolExecutions.any((t) => t.toolData?.status == ToolStatus.pending));
    if (msgIndex == -1) return;
    
    final message = messages[msgIndex];
    final toolExecs = List<ToolExecution>.from(message.toolExecutions);
    final pendingIdx = toolExecs.lastIndexWhere((t) => t.toolData?.status == ToolStatus.pending);
    
    if (pendingIdx != -1) {
      final pendingTool = toolExecs[pendingIdx];
      if (pendingTool.toolData is VaultApprovalTool) {
         final oldData = pendingTool.toolData as VaultApprovalTool;
         final newData = VaultApprovalTool(
            status: ToolStatus.fromJson(newStatus),
            query: oldData.query,
            reason: oldData.reason,
            envVarPrefix: oldData.envVarPrefix,
            response: newStatus == 'resolved' ? 'Credentials approved optimistically.' : 'Request denied.'
         );
         toolExecs[pendingIdx] = pendingTool.copyWith(toolData: newData);
      }
      
      messages[msgIndex] = message.copyWith(toolExecutions: toolExecs);
      value = AsyncValue.data(List.from(messages));
    }
  }
}

final chatControllerProvider = Provider.autoDispose.family<ChatController, String>((ref, chatId) {
  final controller = ChatController(ref, chatId);
  ref.onDispose(controller.dispose);
  return controller;
});

final sendMessageProvider = Provider<void Function(String, String)>((ref) {
  return (chatId, content) async {
    ref.read(chatControllerProvider(chatId)).sendMessageOptimistically(content, chatId);
  };
});

final approveVaultRequestProvider = Provider<Future<void> Function({
  required String chatId,
  required String connectionId,
  required String vaultItemId,
  required String grantDuration,
  String? envVarPrefix,
})>((ref) {
  return ({
    required chatId,
    required connectionId,
    required vaultItemId,
    required grantDuration,
    envVarPrefix,
  }) async {
    final dio = ref.read(dioProvider);
    await dio.post('/vaults/approve', data: {
      'chat_id': chatId,
      'connection_id': connectionId,
      'vault_item_id': vaultItemId,
      'grant_duration': grantDuration,
      'env_var_prefix': envVarPrefix,
    });
    ref.read(chatControllerProvider(chatId)).resolvePendingTool('resolved');
  };
});

final denyVaultRequestProvider = Provider<Future<void> Function(String)>((ref) {
  return (chatId) async {
    final dio = ref.read(dioProvider);
    await dio.post('/vaults/deny', data: {'chat_id': chatId});
    ref.read(chatControllerProvider(chatId)).resolvePendingTool('denied');
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
