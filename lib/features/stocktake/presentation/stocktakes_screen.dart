import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tajer/l10n/app_localizations.dart';

import '../../../core/providers/effective_merchant.dart';
import '../../../core/theme/glass_card.dart';
import '../../authentication/data/auth_repository.dart';
import '../../branches/presentation/active_branch_selector.dart';
import '../../branches/presentation/branch_context.dart';
import '../data/stocktake_repository.dart';

class StocktakesScreen extends ConsumerWidget {
  const StocktakesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final branchId = ref.watch(selectedBranchIdProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.stocktake ?? 'Stocktake', style: const TextStyle(fontFamily: 'Tajawal')),
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: ActiveBranchSelector(compact: true),
          ),
          if (branchId == null)
            Expanded(
              child: Center(
                child: Text(
                  isAr ? 'الرجاء اختيار فرع للبدء' : 'Please select a branch to start',
                  style: const TextStyle(fontFamily: 'Tajawal'),
                ),
              ),
            )
          else
            Expanded(
              child: Consumer(
                builder: (context, ref, child) {
                  final sessionsAsync = ref.watch(stocktakeSessionsProvider(branchId));
                  return sessionsAsync.when(
                    data: (sessions) {
                      if (sessions.isEmpty) {
                        return Center(
                          child: Text(
                            isAr ? 'لا يوجد عمليات جرد سابقة.' : 'No previous stocktakes.',
                            style: const TextStyle(fontFamily: 'Tajawal'),
                          ),
                        );
                      }
                      
                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: sessions.length,
                        itemBuilder: (context, index) {
                          final session = sessions[index];
                          final color = _getStatusColor(session.status);
                          
                          return GlassCard(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: CircleAvatar(backgroundColor: color.withOpacity(0.2), child: Icon(Icons.assignment, color: color)),
                              title: Text(
                                '${isAr ? 'جرد' : 'Stocktake'} - ${session.createdAt.toLocal().toString().split('.')[0]}',
                                style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                '${isAr ? 'الحالة' : 'Status'}: ${_getStatusName(session.status, isAr)} | ${isAr ? 'بواسطة' : 'By'}: ${session.createdByName}',
                                style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12),
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                context.push('/stocktake_session/${session.id}');
                              },
                            ),
                          );
                        },
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, st) => Center(child: Text('Error: $e')),
                  );
                },
              ),
            ),
        ],
      ),
      floatingActionButton: branchId != null
          ? FloatingActionButton.extended(
              onPressed: () async {
                final user = ref.read(appUserProvider).value;
                if (user == null) return;
                
                // Ensure no 'counting' session exists
                final sessions = ref.read(stocktakeSessionsProvider(branchId)).value ?? [];
                if (sessions.any((s) => s.status == 'counting')) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(isAr ? 'يوجد جرد قيد التقدم حالياً' : 'A stocktake is already in progress')),
                  );
                  return;
                }
                
                final repo = ref.read(stocktakeRepositoryProvider);
                final session = await repo.createSession(
                  merchantId: currentEffectiveMerchantId(user),
                  branchId: branchId,
                  createdByUid: user.id,
                  createdByName: user.name ?? 'Unknown',
                );
                
                if (context.mounted) {
                  context.push('/stocktake_session/${session.id}');
                }
              },
              icon: const Icon(Icons.add),
              label: Text(isAr ? 'بدء جرد جديد' : 'New Stocktake', style: const TextStyle(fontFamily: 'Tajawal')),
            )
          : null,
    );
  }
  
  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed': return Colors.green;
      case 'counting': return Colors.orange;
      case 'review': return Colors.blue;
      default: return Colors.grey;
    }
  }
  
  String _getStatusName(String status, bool isAr) {
    switch (status) {
      case 'completed': return isAr ? 'مكتمل' : 'Completed';
      case 'counting': return isAr ? 'قيد الجرد' : 'Counting';
      case 'review': return isAr ? 'مراجعة' : 'Review';
      default: return status;
    }
  }
}
