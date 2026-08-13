import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../domain/shift.dart';
import '../../../core/theme/glass_card.dart';
import '../../expenses/data/expense_repository.dart';

class ShiftDetailsScreen extends ConsumerWidget {
  final Shift shift;
  const ShiftDetailsScreen({super.key, required this.shift});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    final expenses = ref.watch(expensesStreamProvider).value ?? [];
    final allShiftExpenses = expenses.where((e) => e.date.isAfter(shift.startTime) && (shift.endTime == null || e.date.isBefore(shift.endTime!)));
    
    final operatingExpensesCash = allShiftExpenses
        .where((e) => !e.isSupplierPayment && e.paymentMethod == 'cash' && e.isFromShiftDrawer && !e.isCancelled)
        .fold(0.0, (sum, e) => sum + e.amount);
    final operatingExpensesNetwork = allShiftExpenses
        .where((e) => !e.isSupplierPayment && e.paymentMethod == 'network' && !e.isCancelled)
        .fold(0.0, (sum, e) => sum + e.amount);
        
    final supplierPaymentsCash = allShiftExpenses
        .where((e) => e.isSupplierPayment && e.paymentMethod == 'cash' && e.isFromShiftDrawer && !e.isCancelled)
        .fold(0.0, (sum, e) => sum + e.amount);
    final supplierPaymentsNetwork = allShiftExpenses
        .where((e) => e.isSupplierPayment && e.paymentMethod == 'network' && !e.isCancelled)
        .fold(0.0, (sum, e) => sum + e.amount);
        
    final totalRefundsCash = shift.refundsCash ?? 0.0;
    final totalRefundsCard = shift.refundsCard ?? 0.0;
    final totalRefundsTransfer = shift.refundsTransfer ?? 0.0;

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
                    _buildRow(isAr ? 'مبيعات الكاش:' : 'Cash Sales:', '${shift.cashSales ?? 0} ${isAr ? 'ر.س' : 'SAR'}', color: Colors.green),
                    _buildRow(isAr ? 'ديون محصلة (كاش):' : 'Debts Collected (Cash):', '${shift.debtCollectionsCash ?? 0} ${isAr ? 'ر.س' : 'SAR'}', color: Colors.teal),
                    if (totalRefundsCash > 0)
                      _buildRow(isAr ? 'إجمالي المرتجعات (كاش):' : 'Total Refunds (Cash):', '-$totalRefundsCash ${isAr ? 'ر.س' : 'SAR'}', color: Colors.red.shade400),
                    if (operatingExpensesCash > 0)
                      _buildRow(isAr ? 'مصروفات تشغيلية (كاش):' : 'Op. Expenses (Cash):', '-$operatingExpensesCash ${isAr ? 'ر.س' : 'SAR'}', color: Colors.red.shade400),
                    if (operatingExpensesNetwork > 0)
                      _buildRow(isAr ? 'مصروفات تشغيلية (شبكة):' : 'Op. Expenses (Network):', '$operatingExpensesNetwork ${isAr ? 'ر.س' : 'SAR'}', color: Colors.orange),
                    if (supplierPaymentsCash > 0)
                      _buildRow(isAr ? 'سداد موردين (كاش):' : 'Supplier (Cash):', '-$supplierPaymentsCash ${isAr ? 'ر.س' : 'SAR'}', color: Colors.red.shade400),
                    if (supplierPaymentsNetwork > 0)
                      _buildRow(isAr ? 'سداد موردين (شبكة):' : 'Supplier (Network):', '$supplierPaymentsNetwork ${isAr ? 'ر.س' : 'SAR'}', color: Colors.orange),
                    const Divider(height: 16),
                    _buildRow(isAr ? 'إجمالي الضريبة:' : 'Total Tax:', '${(shift.totalTax ?? 0).toStringAsFixed(2)} ${isAr ? 'ر.س' : 'SAR'}', color: Colors.grey.shade600),
                    const Divider(height: 16),
                    _buildRow(isAr ? 'إجمالي مبيعات مدى:' : 'Total Mada Sales:', '${shift.cardTotal ?? 0} ${isAr ? 'ر.س' : 'SAR'}'),
                    if (totalRefundsCard > 0)
                      _buildRow(isAr ? 'مرتجعات مدى:' : 'Refunds (Mada):', '-$totalRefundsCard ${isAr ? 'ر.س' : 'SAR'}', color: Colors.red.shade400),
                    const Divider(height: 16),
                    _buildRow(isAr ? 'إجمالي الحوالات البنكية:' : 'Total Bank Transfers:', '${shift.transferTotal ?? 0} ${isAr ? 'ر.س' : 'SAR'}'),
                    if (totalRefundsTransfer > 0)
                      _buildRow(isAr ? 'مرتجعات حوالات:' : 'Refunds (Transfer):', '-$totalRefundsTransfer ${isAr ? 'ر.س' : 'SAR'}', color: Colors.red.shade400),
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

  Widget _buildRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontFamily: 'Tajawal', color: color ?? Colors.grey)),
          Text(value, style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, color: color)),
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
                        ? Colors.green.withValues(alpha: 0.1) 
                        : (hasShortage ? Colors.red.withValues(alpha: 0.1) : Colors.amber.withValues(alpha: 0.1)),
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
