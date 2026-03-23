import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/tasks_provider.dart';

class TasksView extends HookConsumerWidget {
  const TasksView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tasksAsync = ref.watch(tasksProvider);

    return tasksAsync.when(
      data: (tasks) {
        if (tasks.isEmpty) {
          return const Center(child: Text('No active tasks.'));
        }
        return ListView.builder(
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            final task = tasks[index];
            return ListTile(
              leading: Icon(Icons.assignment_outlined, color: theme.colorScheme.primary),
              title: Text(task.title ?? task.id, style: theme.textTheme.bodyMedium),
              subtitle: Text('Status: ${task.status ?? 'Unknown'}'),
              trailing: PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'delete') {
                    ref.read(deleteTaskProvider)(task.id);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
              onTap: () {
                if (task.chatId != null) {
                  context.push('/chat/${task.chatId}', extra: task.title);
                }
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error loading tasks: $err')),
    );
  }
}
