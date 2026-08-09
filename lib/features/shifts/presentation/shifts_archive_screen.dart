import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tajer/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import '../data/shift_repository.dart';
import '../domain/shift.dart';
import '../../../core/theme/glass_card.dart';
import 'shift_details_screen.dart';

class ShiftsArchiveScreen extends ConsumerWidget {
  const ShiftsArchiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final shiftsAsync = ref.watch(shiftsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(isAr ? 'أرشيف الورديات' : 'Shifts Archive',
            style: const TextStyle(
                fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
      ),
      body: shiftsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
        data: (shifts) {
          final closedShifts =
              shifts.where((s) => s.status == 'closed').toList();
          closedShifts.sort((a, b) =>
              (b.endTime ?? b.startTime).compareTo(a.endTime ?? a.startTime));

          if (closedShifts.isEmpty) {
            return Center(
              child: Text(
                isAr ? 'لا توجد ورديات مغلقة بعد' : 'No closed shifts yet',
                style: const TextStyle(
                    fontFamily: 'Tajawal', fontSize: 18, color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: closedShifts.length,
            itemBuilder: (context, index) {
              final shift = closedShifts[index];
              return _buildShiftCard(context, shift, isAr);
            },
          );
        },
      ),
    );
  }

  Widget _buildShiftCard(BuildContext context, Shift shift, bool isAr) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    // Check all three for summary
    final diffCash = (shift.actualCash ?? 0.0) - (shift.expectedCash ?? 0.0);
    final diffCard = (shift.actualCard ?? 0.0) - (shift.cardTotal ?? 0.0);
    final diffTransfer =
        (shift.actualTransfer ?? 0.0) - (shift.transferTotal ?? 0.0);

    final isFullyMatched = diffCash == 0 && diffCard == 0 && diffTransfer == 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => ShiftDetailsScreen(shift: shift)));
        },
        child: GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person, color: Colors.blueGrey),
                        const SizedBox(width: 8),
                        Text(
                          shift.employeeName,
                          style: const TextStyle(
                              fontFamily: 'Tajawal',
                              fontWeight: FontWeight.bold,
                              fontSize: 16),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          shift.branchId,
                          style: const TextStyle(
                              fontFamily: 'Tajawal',
                              color: Colors.grey,
                              fontSize: 12),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: isFullyMatched
                            ? Colors.green.withOpacity(0.1)
                            : Colors.amber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color:
                                isFullyMatched ? Colors.green : Colors.amber),
                      ),
                      child: Text(
                        isFullyMatched
                            ? (isAr ? 'مطابق كلياً' : 'Fully Matched')
                            : (isAr ? 'يوجد فروقات' : 'Has Differences'),
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontWeight: FontWeight.bold,
                          color: isFullyMatched
                              ? Colors.green.shade700
                              : Colors.amber.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(isAr ? 'الفتح:' : 'Opened:',
                              style: const TextStyle(
                                  fontFamily: 'Tajawal',
                                  color: Colors.grey,
                                  fontSize: 12)),
                          Text(dateFormat.format(shift.startTime),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(isAr ? 'الإغلاق:' : 'Closed:',
                              style: const TextStyle(
                                  fontFamily: 'Tajawal',
                                  color: Colors.grey,
                                  fontSize: 12)),
                          Text(
                              shift.endTime != null
                                  ? dateFormat.format(shift.endTime!)
                                  : '-',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMiniStat(
                          isAr ? 'المتوقع (كاش)' : 'Exp. Cash',
                          (shift.expectedCash ?? 0.0).toStringAsFixed(2),
                          Colors.blue.shade800,
                          isAr),
                      _buildMiniStat(
                          isAr ? 'الفعلي (كاش)' : 'Act. Cash',
                          (shift.actualCash ?? 0.0).toStringAsFixed(2),
                          Theme.of(context).textTheme.bodyLarge?.color ??
                              Colors.black,
                          isAr),
                      _buildMiniStat(
                          isAr ? 'مبيعات الكاش' : 'Cash Sales',
                          (shift.cashSales ?? 0).toStringAsFixed(2),
                          Colors.green,
                          isAr),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('اضغط للتفاصيل >',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontFamily: 'Tajawal')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color, bool isAr) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(
                fontFamily: 'Tajawal', fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text('$value ${isAr ? 'ر.س' : 'SAR'}',
            style: TextStyle(
                fontFamily: 'Tajawal',
                fontWeight: FontWeight.bold,
                color: color)),
      ],
    );
  }
}
