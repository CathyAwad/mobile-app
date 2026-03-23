import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/chats_provider.dart';
import '../../../providers/spaces_provider.dart';

class SpaceScreen extends HookConsumerWidget {
  final String spaceId;
  final String spaceName;

  const SpaceScreen({
    super.key,
    required this.spaceId,
    required this.spaceName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final textController = useTextEditingController();
    final spacesAsync = ref.watch(spacesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.folder_outlined),
            const SizedBox(width: 8),
            Text(spaceName),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.outline.withOpacity(0.5)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Icon(Icons.add),
                  ),
                  Expanded(
                    child: TextField(
                      controller: textController,
                      decoration: const InputDecoration(
                        hintText: 'Send a message to start a new chat...',
                        border: InputBorder.none,
                      ),
                      onSubmitted: (val) => _createChatWithMessage(context, ref, val),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: () => _createChatWithMessage(context, ref, textController.text),
                  ),
                ],
              ),
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'CHATS',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Expanded(
            child: spacesAsync.when(
              data: (spaces) {
                final space = spaces.firstWhere((s) => s.id == spaceId, orElse: () => throw Exception('Space not found'));
                final spaceChats = space.chats ?? [];
                
                if (spaceChats.isEmpty) {
                  return const Center(child: Text('No chats in this space yet.'));
                }
                return ListView.builder(
                  itemCount: spaceChats.length,
                  itemBuilder: (context, index) {
                    final chat = spaceChats[index];
                    return ListTile(
                      leading: Icon(Icons.chat_bubble_outline, color: theme.colorScheme.primary),
                      title: Text(chat.title ?? 'New Chat', style: theme.textTheme.bodyMedium),
                      onTap: () {
                        context.push('/chat/${chat.id}', extra: chat.title);
                      },
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createChatWithMessage(BuildContext context, WidgetRef ref, String content) async {
    final text = content.trim();
    if (text.isEmpty) return;
    
    try {
      final newChat = await ref.read(createChatProvider)(spaceId: spaceId);
      ref.read(sendMessageProvider)(newChat.id, text);
      if (context.mounted) {
        context.push('/chat/${newChat.id}', extra: newChat.title);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}
