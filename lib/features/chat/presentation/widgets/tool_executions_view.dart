import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:frona_mobile/features/chat/domain/tool_model.dart';
import 'package:frona_mobile/features/chat/presentation/widgets/credential_request_card.dart';

class ToolExecutionsView extends HookWidget {
  final List<ToolExecution> tools;
  final String chatId;

  const ToolExecutionsView({super.key, required this.tools, required this.chatId});

  @override
  Widget build(BuildContext context) {
    final hasPendingTool = tools.any((t) => t.toolData?.status == ToolStatus.pending);
    final isExpanded = useState(hasPendingTool);
    final theme = Theme.of(context);

    if (tools.isEmpty) return const SizedBox();

    if (!isExpanded.value) {
      return InkWell(
        onTap: () => isExpanded.value = true,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.build_outlined, size: 16, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                'Used ${tools.length} tool${tools.length > 1 ? 's' : ''} >',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 8, left: 16, right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...tools.asMap().entries.map((entry) {
            final index = entry.key;
            final tool = entry.value;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (tool.turnText != null && tool.turnText!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    margin: const EdgeInsets.only(left: 16, bottom: 8, top: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(tool.turnText!, style: theme.textTheme.bodyMedium),
                  ),
                ToolExecutionTile(index: index, tool: tool, chatId: chatId),
              ],
            );
          }),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => isExpanded.value = false,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.build_outlined, size: 16, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text(
                    'Hide ${tools.length} tool${tools.length > 1 ? 's' : ''} ^',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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

class ToolExecutionTile extends HookWidget {
  final int index;
  final ToolExecution tool;
  final String chatId;

  const ToolExecutionTile({super.key, required this.index, required this.tool, required this.chatId});

  @override
  Widget build(BuildContext context) {
    final isPending = tool.toolData?.status == ToolStatus.pending;
    final isExpanded = useState(isPending);
    final theme = Theme.of(context);

    // Format title strictly to match the screenshot "Request Credentials — request_credentials"
    final rawName = tool.name;
    final title = rawName.replaceAll('_', ' ').split(' ').map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '').join(' ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => isExpanded.value = !isExpanded.value,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tool.success ? Colors.green.withOpacity(0.15) : theme.colorScheme.errorContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${index + 1}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: tool.success ? Colors.green : theme.colorScheme.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '— $rawName',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  isExpanded.value ? Icons.expand_less : Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        if (isExpanded.value)
          Padding(
            padding: const EdgeInsets.only(left: 36.0, right: 0.0, bottom: 8.0),
            child: _buildExpandedContent(context),
          ),
      ],
    );
  }

  Widget _buildExpandedContent(BuildContext context) {
    if (tool.toolData is VaultApprovalTool) {
      return CredentialRequestCard(
        chatId: chatId,
        tool: tool.toolData as VaultApprovalTool,
      );
    }

    final theme = Theme.of(context);
    String argsDisplay = '';
    
    if (tool.arguments is Map) {
      final map = tool.arguments as Map;
      if (tool.name == 'shell' && map.containsKey('command')) {
        argsDisplay = map['command'].toString();
      } else {
        try {
          argsDisplay = const JsonEncoder.withIndent('  ').convert(map);
        } catch (_) {
          argsDisplay = tool.arguments.toString();
        }
      }
    } else {
      argsDisplay = tool.arguments.toString();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            argsDisplay,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          ),
          if (tool.result.isNotEmpty) ...[
            const SizedBox(height: 12),
            Divider(color: theme.dividerColor.withOpacity(0.2)),
            const SizedBox(height: 8),
            Text(
              'Result:',
              style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            Text(
              tool.result,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
          ]
        ],
      ),
    );
  }
}
