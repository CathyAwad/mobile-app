import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/chats_provider.dart';
import '../../../providers/spaces_provider.dart';
import '../../chat/domain/chat_model.dart';

class ChatsView extends HookConsumerWidget {
  const ChatsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tabController = useTabController(initialLength: 3, initialIndex: 1);
    useListenable(tabController);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          TabBar(
            controller: tabController,
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
            indicatorColor: theme.colorScheme.primary,
            tabs: const [
              Tab(text: 'SPACES'),
              Tab(text: 'CHATS'),
              Tab(text: 'ARCHIVED'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: tabController,
              children: [
                _buildSpacesList(context, ref, theme),
                _buildChatsList(context, ref, theme, chatsProvider),
                _buildChatsList(context, ref, theme, archivedChatsProvider),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: tabController.index == 2 ? null : FloatingActionButton(
        onPressed: () async {
          if (tabController.index == 0) {
            _showCreateSpaceDialog(context, ref);
          } else if (tabController.index == 1) {
            context.push('/chat/new:default');
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showCreateSpaceDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('New Space'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'Space Name'),
            autofocus: true,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  await ref.read(createSpaceProvider)(name);
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSpacesList(BuildContext context, WidgetRef ref, ThemeData theme) {
    final spacesAsync = ref.watch(spacesProvider);

    return spacesAsync.when(
      data: (spaces) {
        if (spaces.isEmpty) return const Center(child: Text('No spaces found.'));
        return ListView.builder(
          itemCount: spaces.length,
          itemBuilder: (context, index) {
            final space = spaces[index];
            return ListTile(
              leading: Icon(Icons.folder_outlined, color: theme.colorScheme.primary),
              title: Text(space.name, style: theme.textTheme.bodyMedium),
              trailing: PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'delete') {
                    ref.read(deleteSpaceProvider)(space.id);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
              onTap: () {
                context.push('/space/${space.id}', extra: space.name);
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildChatsList(
    BuildContext context, 
    WidgetRef ref, 
    ThemeData theme, 
    FutureProvider<List<Chat>> provider,
  ) {
    final chatsAsync = ref.watch(provider);

    return chatsAsync.when(
      data: (chats) {
        if (chats.isEmpty) return const Center(child: Text('No chats found.'));
        return ListView.builder(
          itemCount: chats.length,
          itemBuilder: (context, index) {
            final chat = chats[index];
            return ListTile(
              leading: Icon(
                provider == archivedChatsProvider ? Icons.archive_outlined : Icons.chat_bubble_outline, 
                color: theme.colorScheme.primary
              ),
              title: Text(chat.title ?? 'New Chat', style: theme.textTheme.bodyMedium),
              trailing: PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'archive') {
                    ref.read(archiveChatProvider)(chat.id);
                  } else if (value == 'unarchive') {
                    ref.read(unarchiveChatProvider)(chat.id);
                  } else if (value == 'delete') {
                    ref.read(deleteChatProvider)(chat.id);
                  }
                },
                itemBuilder: (context) {
                  if (provider == archivedChatsProvider) {
                    return [
                      const PopupMenuItem(value: 'unarchive', child: Text('Unarchive')),
                      const PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ];
                  } else {
                    return [
                      const PopupMenuItem(value: 'archive', child: Text('Archive')),
                      const PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ];
                  }
                },
              ),
              onTap: () {
                context.push('/chat/${chat.id}', extra: chat.title);
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }
}
