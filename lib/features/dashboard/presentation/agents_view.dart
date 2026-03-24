import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/agents_provider.dart';

class AgentsView extends HookConsumerWidget {
  const AgentsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final agentsAsync = ref.watch(agentsProvider);

    return agentsAsync.when(
      data: (agents) {
        if (agents.isEmpty) {
          return const Center(child: Text('No agents found.'));
        }
        return ListView.builder(
          itemCount: agents.length,
          itemBuilder: (context, index) {
            final agent = agents[index];
            return ListTile(
              leading: Icon(
                Icons.smart_toy_outlined, 
                color: agent.enabled ? theme.colorScheme.primary : theme.disabledColor
              ),
              title: Text(agent.name, style: theme.textTheme.bodyMedium),
              subtitle: agent.description != null ? Text(agent.description!, maxLines: 1) : null,
              trailing: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: agent.enabled ? Colors.greenAccent : Colors.grey,
                ),
              ),
              onTap: () {
                context.push('/chat/new:${agent.id}', extra: agent.name);
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error loading agents: $err')),
    );
  }
}
