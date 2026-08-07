import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../domain/shift.dart';
import '../../../core/theme/glass_card.dart';

class ShiftDetailsScreen extends StatelessWidget {
  final Shift shift;
  const ShiftDetailsScreen({super.key, required this.shift});

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
    
    // Cash
    final expectedCash = shift.expectedCash ?? 0.0;
    final actualCash = shift.actualCash ?? 0.0;
    final diffCash = actualCash - expectedCash;
    
    // Card (Mada)
    final expectedCard = shift.cardTotal ?? 0.0;
    final actualCard = shift.actualCard ?? 0.0;
    final diffCard = actualCard - expectedCard;
    
    // Transfer
    final expectedTransfer = shift.transferTotal ?? 0.0;
    final actualTransfer = shift.actualTransfer ?? 0.0;
    final diffTransfer = actualTransfer - expectedTransfer;

    return Scaffold(
      appBar: AppBar(
        title: Text(isAr ? 'تفاصيل الوردية' : 'Shift Details', style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // General Info Card
            GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person, color: Colors.blueGrey),
                        const SizedBox(width: 8),
                        Text(
                          shift.employeeName,
                          style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    _buildRow(isAr ? 'الفتح:' : 'Opened:', dateFormat.format(shift.startTime)),
                    _buildRow(isAr ? 'الإغلاق:' : 'Closed:', shift.endTime != null ? dateFormat.format(shift.endTime!) : '-'),
                    const Divider(height: 24),
                    _buildRow(isAr ? 'العهدة الافتتاحية:' : 'Opening Cash:', '${shift.startCash} ${isAr ? 'ر.س' : 'SAR'}'),
                    _buildRow(isAr ? 'مبيعات الكاش:' : 'Cash Sales:', '${shift.cashSales ?? 0} ${isAr ? 'ر.س' : 'SAR'}'),
                    _buildRow(isAr ? 'ديون محصلة (كاش):' : 'Debts Collected (Cash):', '${shift.debtCollectionsCash ?? 0} ${isAr ? 'ر.س' : 'SAR'}'),
                    _buildRow(isAr ? 'إجمالي الضريبة:' : 'Total Tax:', '${(shift.totalTax ?? 0).toStringAsFixed(2)} ${isAr ? 'ر.س' : 'SAR'}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Payment Methods Comparison
            Text(isAr ? 'تفاصيل المطابقة' : 'Matching Details', style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),
            
            _buildComparisonCard(
              title: isAr ? 'الكاش (النقد)' : 'Cash',
              expected: expectedCash,
              actual: actualCash,
              diff: diffCash,
              isAr: isAr,
              context: context,
            ),
            const SizedBox(height: 12),
            
            _buildComparisonCard(
              title: isAr ? 'مدى (البطاقة)' : 'Mada (Card)',
              expected: expectedCard,
              actual: actualCard,
              diff: diffCard,
              isAr: isAr,
              context: context,
            ),
            const SizedBox(height: 12),
            
            _buildComparisonCard(
              title: isAr ? 'التحويل البنكي' : 'Bank Transfer',
              expected: expectedTransfer,
              actual: actualTransfer,
              diff: diffTransfer,
              isAr: isAr,
              context: context,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontFamily: 'Tajawal', color: Colors.grey)),
          Text(value, style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildComparisonCard({
    required String title,
    required double expected,
    required double actual,
    required double diff,
    required bool isAr,
    required BuildContext context,
  }) {
    final hasShortage = diff < 0;
    final isMatched = diff == 0;
    
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 16)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: isMatched 
                        ? Colors.green.withOpacity(0.1) 
                        : (hasShortage ? Colors.red.withOpacity(0.1) : Colors.amber.withOpacity(0.1)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isMatched ? Colors.green : (hasShortage ? Colors.red : Colors.amber),
                    ),
                  ),
                  child: Text(
                    isMatched 
                      ? (isAr ? 'مطابق' : 'Matched')
                      : (hasShortage 
                          ? (isAr ? 'عجز: ${diff.abs().toStringAsFixed(2)}' : 'Short: ${diff.abs().toStringAsFixed(2)}') 
                          : (isAr ? 'فائض: ${diff.toStringAsFixed(2)}' : 'Over: ${diff.toStringAsFixed(2)}')),
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontWeight: FontWeight.bold,
                      color: isMatched ? Colors.green.shade700 : (hasShortage ? Colors.red : Colors.amber.shade700),
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(isAr ? 'المتوقع' : 'Expected', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text('${expected.toStringAsFixed(2)} ${isAr ? 'ر.س' : 'SAR'}', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, color: Colors.blue.shade800)),
                  ],
                ),
                Column(
                  children: [
                    Text(isAr ? 'الفعلي' : 'Actual', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text('${actual.toStringAsFixed(2)} ${isAr ? 'ر.س' : 'SAR'}', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
