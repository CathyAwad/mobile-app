import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import '../../../providers/chats_provider.dart';

class ChatScreen extends HookConsumerWidget {
  final String chatId;
  final String? title;

  const ChatScreen({super.key, required this.chatId, this.title});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final textController = useTextEditingController();

    final messagesAsync = ref.watch(chatMessagesProvider(chatId));

    return Scaffold(
      appBar: AppBar(
        title: Text(title ?? 'Chat'),
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
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isUser = msg.role == 'user';
                    return Align(
                      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isUser ? theme.colorScheme.primary.withOpacity(0.1) : theme.colorScheme.secondary,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isUser ? theme.colorScheme.primary.withOpacity(0.3) : theme.colorScheme.surface,
                          ),
                        ),
                        constraints: const BoxConstraints(maxWidth: 600),
                        child: Text(
                          msg.content,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    );
                  },
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
                  IconButton(
                    icon: Icon(Icons.send, color: theme.colorScheme.onSurface.withOpacity(0.5)),
                    onPressed: () {
                      final content = textController.text.trim();
                      if (content.isNotEmpty) {
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
