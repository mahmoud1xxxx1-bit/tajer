import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tajer/l10n/app_localizations.dart';
import '../data/daily_summary_repository.dart';
import '../../../core/providers/effective_merchant.dart';
import '../../authentication/data/auth_repository.dart';

class DailySummariesScreen extends ConsumerWidget {
  const DailySummariesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final summariesAsync = ref.watch(dailySummariesProvider);
    
    return Scaffold(
      appBar: AppBar(title: Text(l10n.dailySummaries ?? 'Daily Summaries')),
      body: summariesAsync.when(
        data: (summaries) {
          if (summaries.isEmpty) {
            return const Center(child: Text('No daily summaries yet.'));
          }
          return ListView.builder(
            itemCount: summaries.length,
            itemBuilder: (context, index) {
              final summary = summaries[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(summary.id),
                  subtitle: Text('Sales: ${summary.sales.toStringAsFixed(2)} | Orders: ${summary.ordersCount} | Profit: ${summary.cogsIncomplete ? "?" : summary.profit.toStringAsFixed(2)}'),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
           final appUser = ref.read(appUserProvider).value;
           if (appUser != null) {
              final merchantId = currentEffectiveMerchantId(appUser);
              final yesterday = DateTime.now().subtract(const Duration(days: 1));
              ref.read(dailySummaryRepositoryProvider).generateSummaryForDate(merchantId, yesterday);
           }
        },
        child: const Icon(Icons.download),
      ),
    );
  }
}
