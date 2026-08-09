import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../domain/shift.dart';
import '../data/shift_repository.dart';
import '../../authentication/data/auth_repository.dart';
import '../../branches/presentation/branch_context.dart';
import '../../../core/services/activity_logger.dart';
import '../../../core/providers/effective_merchant.dart';

class StartShiftDialog extends ConsumerStatefulWidget {
  const StartShiftDialog({super.key});

  @override
  ConsumerState<StartShiftDialog> createState() => _StartShiftDialogState();
}

class _StartShiftDialogState extends ConsumerState<StartShiftDialog> {
  final _cashController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _cashController.dispose();
    super.dispose();
  }

  Future<void> _startShift() async {
    final cash = double.tryParse(_cashController.text) ?? 0.0;
    final user = ref.read(appUserProvider).value;
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      final branchId = ref.read(selectedBranchIdProvider);
      final shift = Shift(
        id: const Uuid().v4(),
        merchantId: currentEffectiveMerchantId(user),
        branchId: branchId,
        employeeId: user.id,
        employeeName: user.name ?? 'Unknown',
        startTime: DateTime.now(),
        startCash: cash,
        status: 'open',
      );
      await ref.read(shiftRepositoryProvider).openShift(shift);
      ActivityLogger.log(
        user: user,
        actionType: 'Start Shift|بدء وردية',
        description:
            'Started a new shift with cash $cash in branch $branchId|بدأ وردية جديدة بعهدة $cash في الفرع $branchId',
      );
    } catch (e) {
      if (mounted) {
        final isAr = Localizations.localeOf(context).languageCode == 'ar';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isAr ? 'خطأ: $e' : 'Error: $e',
                style: const TextStyle(fontFamily: 'Tajawal'))));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.point_of_sale, color: Colors.amber, size: 28),
          const SizedBox(width: 10),
          Text(isAr ? 'بداية وردية جديدة' : 'Start New Shift',
              style: const TextStyle(
                  fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.indigo.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.indigo.withOpacity(0.3)),
              ),
              child: Text(
                isAr
                    ? '💡 لماذا نفتح وردية؟\nنظام الورديات يحمي أموالك! أدخل المبلغ الموجود في الدرج قبل بدء البيع، وسيقوم النظام بحساب مبيعات اليوم ومقارنتها تلقائياً بالدرج لكشف أي عجز أو تلاعب نهاية الوردية.'
                    : '💡 Why open a shift?\nThe shift system protects your money! Enter the amount in the drawer before selling, and the system will calculate today\'s sales and automatically compare it with the drawer to detect any shortage at the end of the shift.',
                style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 13,
                    height: 1.5,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.7)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
                isAr
                    ? 'أدخل مبلغ العهدة الافتتاحية (الكاش الموجود حالياً في الدرج):'
                    : 'Enter Opening Amount (Cash currently in drawer):',
                style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: _cashController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: isAr
                    ? 'مبلغ العهدة (مثال: 100)'
                    : 'Opening Amount (e.g., 100)',
                labelStyle: const TextStyle(fontFamily: 'Tajawal'),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                suffixText: isAr ? 'ر.س' : 'SAR',
              ),
            ),
          ],
        ),
      ),
      actions: [
        _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _startShift,
                icon: const Icon(Icons.play_arrow),
                label: Text(
                    isAr ? 'بدء الوردية والبيع الآن' : 'Start Shift & Sell Now',
                    style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
              ),
      ],
    );
  }
}
