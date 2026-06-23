import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sentery_app/core/constants/app_colors.dart';
import 'package:sentery_app/core/constants/app_text_styles.dart';
import 'package:sentery_app/core/services/audit_service.dart';
import 'package:sentery_app/core/widgets/app_card.dart';

final auditLogsProvider = FutureProvider((ref) {
  return ref.watch(auditServiceProvider).getLogs();
});

class AuditLogScreen extends ConsumerWidget {
  const AuditLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(auditLogsProvider);
    final dateFmt = DateFormat('dd MMM, hh:mm a');

    return Scaffold(
      appBar: AppBar(title: const Text('System Audit Logs')),
      body: logsAsync.when(
        data: (logs) {
          if (logs.isEmpty) {
            return const Center(child: Text('No activity recorded yet'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              final (icon, color) = _describeAction(log.actionName);
              return AppCard(
                margin: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                      child: Icon(icon, color: color, size: 16),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${log.actionName.toUpperCase()} — ${log.targetTable}',
                              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
                          Text('Record #${log.recordId}  •  ${dateFmt.format(log.createdAt)}', style: AppTextStyles.caption),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }

  (IconData, Color) _describeAction(String action) {
    switch (action) {
      case 'create': return (Icons.add_circle_outline, AppColors.success);
      case 'update': return (Icons.edit_outlined, AppColors.warning);
      case 'delete': return (Icons.delete_outline, AppColors.danger);
      default: return (Icons.circle_outlined, AppColors.textSecondary);
    }
  }
}
