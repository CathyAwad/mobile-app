import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:frona_mobile/providers/chats_provider.dart';
import 'package:frona_mobile/features/chat/domain/message_model.dart';
import 'package:frona_mobile/features/chat/presentation/widgets/tool_executions_view.dart';
import 'package:frona_mobile/providers/agents_provider.dart';
import 'package:collection/collection.dart';
import 'package:go_router/go_router.dart';

class ChatScreen extends HookConsumerWidget {
  final String chatId;
  final String? title;
  final String? initialMessage;

  const ChatScreen({super.key, required this.chatId, this.title, this.initialMessage});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final textController = useTextEditingController();
    final scrollController = useScrollController();
    final isAtBottom = useRef(true);

    final controller = ref.watch(chatControllerProvider(chatId));
    final messagesAsync = useValueListenable(controller);
    final messages = messagesAsync.value ?? [];

    final isNewChat = chatId.startsWith('new:');
    final creatingChat = useState(false);
    
    final hasSentInitial = useRef(false);
    final isMessagesLoading = messagesAsync.isLoading;
    
    useEffect(() {
      if (initialMessage != null && initialMessage!.isNotEmpty && !hasSentInitial.value && !isNewChat && !isMessagesLoading) {
        hasSentInitial.value = true;
        Future.microtask(() {
          ref.read(sendMessageProvider)(chatId, initialMessage!);
        });
      }
      return null;
    }, [initialMessage, chatId, isNewChat, isMessagesLoading]);

    final chatAsync = ref.watch(chatProvider(chatId));
    final agentsAsync = ref.watch(agentsProvider);
    
    final displayAgentName = useMemoized(() {
      final chat = chatAsync.value;
      if (chat == null || chatId.startsWith('new:')) {
        if (chatId.startsWith('new:')) {
           final parts = chatId.split(':');
           if (parts.length > 1 && parts[1] != 'default') {
             final agents = agentsAsync.value;
             final agent = agents?.firstWhereOrNull((a) => a.id == parts[1]);
             return agent?.name ?? 'Assistant';
           }
        }
        return 'Assistant';
      }
      
      final agents = agentsAsync.value;
      if (agents == null) return 'Assistant';
      
      final agent = agents.firstWhereOrNull((a) => a.id == chat.agentId);
      return agent?.name ?? 'Assistant';
    }, [chatId, chatAsync.value, agentsAsync.value]);

    final displayTitle = title ?? chatAsync.value?.title ?? (chatId.startsWith('new:') ? 'New chat' : 'Chat');

    useEffect(() {
      void listener() {
        if (!scrollController.hasClients) return;
        isAtBottom.value = scrollController.position.maxScrollExtent - scrollController.offset < 150;
      }
      scrollController.addListener(listener);
      return () => scrollController.removeListener(listener);
    }, [scrollController]);

    useEffect(() {
      if (isAtBottom.value && messages.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (scrollController.hasClients) {
            scrollController.animateTo(
              scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
            );
          }
        });
      }
      return null;
    }, [messages.length, messages.lastOrNull?.content.length, messages.lastOrNull?.toolExecutions.length]);

    // Initial jump to bottom on load
    useEffect(() {
      if (messages.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (scrollController.hasClients) {
            scrollController.jumpTo(scrollController.position.maxScrollExtent);
          }
        });
      }
      return null;
    }, [messages.isEmpty]);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(displayTitle, style: theme.textTheme.titleMedium),
            Text(
              displayAgentName, 
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          ref.watch(chatProvider(chatId)).when(
            data: (chat) => PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) async {
                if (value == 'archive') {
                  await ref.read(archiveChatProvider)(chatId);
                  if (context.mounted) Navigator.pop(context);
                } else if (value == 'unarchive') {
                  await ref.read(unarchiveChatProvider)(chatId);
                } else if (value == 'delete') {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete Chat'),
                      content: const Text('Are you sure you want to delete this chat?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.error),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await ref.read(deleteChatProvider)(chatId);
                    if (context.mounted) Navigator.pop(context);
                  }
                }
              },
              itemBuilder: (context) {
                final isArchived = chat.archivedAt != null;
                return [
                  PopupMenuItem(
                    value: chat.taskId != null ? null : (isArchived ? 'unarchive' : 'archive'),
                    child: Row(
                      children: [
                        Icon(isArchived ? Icons.unarchive_outlined : Icons.archive_outlined, size: 20),
                        const SizedBox(width: 8),
                        Text(isArchived ? 'Unarchive' : 'Archive'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 20),
                        const SizedBox(width: 8),
                        Text('Delete'),
                      ],
                    ),
                  ),
                ];
              },
            ),
            loading: () => const SizedBox(),
            error: (_, __) => const SizedBox(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              data: (messages) {
                if (messages.isEmpty) {
                  return const Center(child: Text('No messages yet. Say hi!'));
                }
                return Align(
                  alignment: Alignment.topCenter,
                  child: ListView.builder(
                    controller: scrollController,
                    reverse: false,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      return MessageBubble(chatId: chatId, message: msg);
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error loading messages: $err')),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(top: BorderSide(color: theme.dividerColor)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.add, color: theme.colorScheme.onSurface.withOpacity(0.5)),
                    onPressed: () {},
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: textController,
                      decoration: const InputDecoration(
                        hintText: 'Send a message...',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                      ),
                    ),
                  ),
                  creatingChat.value ? 
                  const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: SizedBox(
                      width: 24, 
                      height: 24, 
                      child: CircularProgressIndicator(strokeWidth: 2)
                    ),
                  ) : IconButton(
                    icon: Icon(Icons.send, color: theme.colorScheme.onSurface.withOpacity(0.5)),
                    onPressed: () async {
                      final content = textController.text.trim();
                      if (content.isEmpty) return;
                      
                      if (isNewChat) {
                        if (creatingChat.value) return;
                        creatingChat.value = true;
                        try {
                           final parts = chatId.split(':');
                           final agentId = (parts.length > 1 && parts[1] != 'default') ? parts[1] : null;
                           final newChat = await ref.read(createChatProvider)(agentId: agentId);
                           if (context.mounted) {
                              context.replace('/chat/${newChat.id}', extra: {
                                'title': newChat.title ?? agentId,
                                'initialMessage': content
                              });
                           }
                        } catch (e) {
                           creatingChat.value = false;
                           if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to start chat: $e')));
                           }
                        }
                      } else {
                        ref.read(sendMessageProvider)(chatId, content);
                        textController.clear();
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MessageBubble extends ConsumerWidget {
  final String chatId;
  final ChatMessage message;

  const MessageBubble({super.key, required this.chatId, required this.message});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isUser = message.role == 'user';
    final isExecuting = message.status == 'executing';

    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: isUser ? theme.colorScheme.primaryContainer : theme.colorScheme.secondaryContainer,
            foregroundColor: isUser ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSecondaryContainer,
            radius: 16,
            child: Text(
              isUser ? 'Y' : 'A',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.content.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isUser ? theme.colorScheme.primary.withOpacity(0.05) : theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.outline.withOpacity(0.1),
                      ),
                    ),
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Text(
                      message.content,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                        height: 1.5,
                      ),
                    ),
                  )
                else if (isExecuting && !isUser && message.toolExecutions.isEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8, top: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.onSurfaceVariant),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Thinking...',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (message.toolExecutions.isNotEmpty)
                  ToolExecutionsView(
                    tools: message.toolExecutions,
                    chatId: chatId,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
