import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:frona_mobile/providers/vaults_provider.dart';
import 'package:frona_mobile/providers/chats_provider.dart';
import 'package:frona_mobile/features/chat/domain/tool_model.dart';
import 'dart:async';

class CredentialRequestCard extends HookConsumerWidget {
  final String chatId;
  final VaultApprovalTool tool;

  const CredentialRequestCard({
    super.key,
    required this.chatId,
    required this.tool,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final vaultsAsync = ref.watch(vaultsProvider);
    
    final selectedVaultId = useState<String?>(null);
    final searchQuery = useState('');
    final debouncedQuery = useState('');
    final selectedItemId = useState<String?>(null);
    final selectedDuration = useState('once');
    final isLoading = useState(false);

    // Debounce search query
    useEffect(() {
      final timer = Timer(const Duration(milliseconds: 500), () {
        debouncedQuery.value = searchQuery.value;
      });
      return timer.cancel;
    }, [searchQuery.value]);

    final itemsAsync = ref.watch(vaultItemsProvider((
      vaultId: selectedVaultId.value ?? '',
      query: debouncedQuery.value,
    )));

    final isResolved = tool.status != ToolStatus.pending;

    if (isResolved) {
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(
                tool.status == ToolStatus.resolved ? Icons.check_circle : Icons.cancel,
                color: tool.status == ToolStatus.resolved ? Colors.green : theme.colorScheme.error,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  tool.status == ToolStatus.resolved 
                    ? 'Credential request approved'
                    : 'Credential request denied',
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.vpn_key, color: theme.colorScheme.onPrimaryContainer),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Credential Request',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'To access your Home Assistant instance',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (tool.reason.isNotEmpty)
              Text(
                tool.reason,
                style: theme.textTheme.bodySmall,
              ),
            const Divider(height: 32),
            
            // Vault Selection
            Text('Vault', style: theme.textTheme.labelMedium),
            const SizedBox(height: 8),
            vaultsAsync.when(
              data: (vaults) => DropdownButtonFormField<String>(
                value: selectedVaultId.value,
                hint: const Text('Select a vault'),
                items: vaults.map((v) => DropdownMenuItem(value: v.id, child: Text(v.name))).toList(),
                onChanged: (val) {
                  selectedVaultId.value = val;
                  selectedItemId.value = null;
                },
                decoration: InputDecoration(
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error loading vaults: $e', style: const TextStyle(color: Colors.red, fontSize: 12)),
            ),
            const SizedBox(height: 16),

            // Item Search & Selection
            if (selectedVaultId.value != null) ...[
              Text('Search', style: theme.textTheme.labelMedium),
              const SizedBox(height: 8),
              TextField(
                onChanged: (val) => searchQuery.value = val,
                decoration: InputDecoration(
                  hintText: 'Search for item...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              const SizedBox(height: 12),
              itemsAsync.when(
                data: (items) {
                  if (items.isEmpty) return const Text('No items found', style: TextStyle(fontSize: 12));
                  return DropdownButtonFormField<String>(
                    value: selectedItemId.value,
                    hint: const Text('Select an item'),
                    items: items.map((i) => DropdownMenuItem(
                      value: i.id, 
                      child: Text('${i.name}${i.username != null ? ' (${i.username})' : ''}'),
                    )).toList(),
                    onChanged: (val) => selectedItemId.value = val,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  );
                },
                loading: () => const Center(child: Padding(padding: EdgeInsets.all(8.0), child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)))),
                error: (e, _) => Text('Error searching items: $e', style: const TextStyle(color: Colors.red, fontSize: 12)),
              ),
              const SizedBox(height: 16),
            ],

            // Duration Dropdown
            Text('Duration', style: theme.textTheme.labelMedium),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: selectedDuration.value,
              items: const [
                DropdownMenuItem(value: 'once', child: Text('Allow once')),
                DropdownMenuItem(value: 'permanent', child: Text('Always allow')),
              ],
              onChanged: (val) => selectedDuration.value = val!,
              decoration: InputDecoration(
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: isLoading.value ? null : () async {
                      isLoading.value = true;
                      try {
                        await ref.read(denyVaultRequestProvider)(chatId);
                      } catch (e) {
                         if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      } finally {
                        if (context.mounted) isLoading.value = false;
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      side: BorderSide(color: theme.colorScheme.error.withOpacity(0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: (selectedItemId.value == null || isLoading.value) ? null : () async {
                      isLoading.value = true;
                      try {
                        await ref.read(approveVaultRequestProvider)(
                          chatId: chatId,
                          connectionId: selectedVaultId.value!,
                          vaultItemId: selectedItemId.value!,
                          grantDuration: selectedDuration.value,
                          envVarPrefix: tool.envVarPrefix,
                        );
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      } finally {
                        if (context.mounted) isLoading.value = false;
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: isLoading.value 
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
