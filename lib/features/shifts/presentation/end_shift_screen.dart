import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/shift.dart';
import '../data/shift_repository.dart';
import '../../authentication/data/auth_repository.dart';
import '../../authentication/domain/app_user.dart';
import '../../../core/services/printer_service.dart';
import '../../../core/providers/store_profile_provider.dart';
import '../../expenses/data/expense_repository.dart';
import '../../../core/theme/glass_card.dart';
import '../../../core/services/activity_logger.dart';

class EndShiftScreen extends ConsumerStatefulWidget {
  const EndShiftScreen({super.key});

  @override
  ConsumerState<EndShiftScreen> createState() => _EndShiftScreenState();
}

class _EndShiftScreenState extends ConsumerState<EndShiftScreen> {
  final _actualCashController = TextEditingController();
  final _actualCardController = TextEditingController();
  final _actualTransferController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _actualCashController.dispose();
    _actualCardController.dispose();
    _actualTransferController.dispose();
    super.dispose();
  }

  Future<void> _closeShift(Shift shift) async {
    final actualCash = double.tryParse(_actualCashController.text);
    final actualCard = double.tryParse(_actualCardController.text) ?? 0.0;
    final actualTransfer = double.tryParse(_actualTransferController.text) ?? 0.0;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    if (actualCash == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isAr ? 'الرجاء إدخال مبلغ صحيح' : 'Please enter a valid amount', style: const TextStyle(fontFamily: 'Tajawal'))));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final updatedShift = shift.copyWith(
        endTime: DateTime.now(),
        actualCash: actualCash,
        actualCard: actualCard,
        actualTransfer: actualTransfer,
        status: 'closed',
      );
      
      await ref.read(shiftRepositoryProvider).closeShift(updatedShift);
      final user = ref.read(appUserProvider).value;
      ActivityLogger.log(
        user: user,
        actionType: 'End Shift|إنهاء وردية',
        description: 'Ended shift with expected cash ${updatedShift.expectedCash} and actual cash $actualCash|تم إنهاء الوردية بمبلغ متوقع ${updatedShift.expectedCash} ومبلغ فعلي $actualCash',
      );
      
      // Print Z-Report
      final storeProfile = ref.read(storeProfileProvider).value;
      try {
        await PrinterService.printZReport(updatedShift, 'ر.س', storeProfile: storeProfile);
      } catch (e) {
        // Just show a snackbar if printing fails, but shift is closed
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم الإغلاق ولكن تعذرت الطباعة: $e', style: TextStyle(fontFamily: 'Tajawal'))));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isAr ? 'تم إغلاق الوردية بنجاح' : 'Shift closed successfully', style: const TextStyle(fontFamily: 'Tajawal'))));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isAr ? 'خطأ: $e' : 'Error: $e', style: const TextStyle(fontFamily: 'Tajawal'))));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(appUserProvider).value;
    final merchantId = user?.merchantId ?? user?.id;
    final shiftAsync = ref.watch(currentShiftProvider(merchantId ?? ''));

    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      appBar: AppBar(
        title: Text(isAr ? 'إغلاق الوردية وجرد الصندوق' : 'Close Shift & Drawer Check', style: const TextStyle(fontFamily: 'Tajawal')),
      ),
      body: shiftAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (shift) {
          if (shift == null) {
            return Center(
              child: Text(isAr ? 'لا توجد وردية مفتوحة حالياً' : 'No open shift currently', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 18)),
            );
          }

          final expenses = ref.watch(expensesStreamProvider).value ?? [];
          final allShiftExpenses = expenses.where((e) => e.date.isAfter(shift.startTime));
          
          final operatingExpenses = allShiftExpenses
              .where((e) => e.category != 'سداد ديون موردين')
              .fold(0.0, (sum, e) => sum + e.amount);
              
          final supplierPayments = allShiftExpenses
              .where((e) => e.category == 'سداد ديون موردين')
              .fold(0.0, (sum, e) => sum + e.amount);

          // Calculate cash expenses
          final totalCashExpenses = operatingExpenses + supplierPayments;
          final totalDebtsCollected = shift.debtCollectionsCash ?? 0.0;
          final totalTax = shift.totalTax ?? 0.0;

          // Expected Cash = Start Cash + Cash Sales + Debts Collected - Expenses
          final expectedCash = shift.startCash + (shift.cashSales ?? 0.0) + totalDebtsCollected - totalCashExpenses;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(isAr ? 'معلومات الوردية' : 'Shift Information', style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 18)),
                        const SizedBox(height: 16),
                        _buildRow(isAr ? 'تاريخ فتح الوردية:' : 'Opened at:', DateFormat('yyyy-MM-dd HH:mm').format(shift.startTime)),
                        _buildRow(isAr ? 'الوردية فُتحت بواسطة:' : 'Opened by:', shift.employeeName),
                        const Divider(height: 32),
                        _buildRow(isAr ? 'رصيد الصندوق الافتتاحي:' : 'Opening Cash:', '${shift.startCash} ${isAr ? 'ر.س' : 'SAR'}'),
                        _buildRow(isAr ? 'مبيعات الكاش (صورة فعلية):' : 'Actual Cash Sales:', '${shift.cashSales ?? 0.0} ${isAr ? 'ر.س' : 'SAR'}', color: Colors.green),
                        _buildRow(isAr ? 'ديون مُحصلة كاش:' : 'Debts Collected (Cash):', '$totalDebtsCollected ${isAr ? 'ر.س' : 'SAR'}', color: Colors.teal),
                        _buildRow(isAr ? 'إجمالي المصروفات (كاش):' : 'Total Expenses (Cash):', '-$totalCashExpenses ${isAr ? 'ر.س' : 'SAR'}', color: Colors.red),
                        const Divider(height: 24),
                        _buildRow(isAr ? 'الكاش المتوقع في الدرج الآن:' : 'Expected Cash in Drawer:', '${expectedCash.toStringAsFixed(2)} ${isAr ? 'ر.س' : 'SAR'}', isBold: true, color: Colors.blue.shade800),
                        const Divider(height: 24),
                        _buildRow(isAr ? 'إجمالي الضريبة المحصلة (للمعلومة):' : 'Total Collected Tax (Info):', '${totalTax.toStringAsFixed(2)} ${isAr ? 'ر.س' : 'SAR'}', color: Colors.grey.shade700),
                        _buildRow(isAr ? 'مبيعات مدى:' : 'Card Sales:', '${shift.cardTotal ?? 0.0} ${isAr ? 'ر.س' : 'SAR'}', color: Colors.blueGrey),
                        _buildRow(isAr ? 'تحويل بنكي:' : 'Bank Transfer:', '${shift.transferTotal ?? 0.0} ${isAr ? 'ر.س' : 'SAR'}', color: Colors.blueGrey),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(isAr ? 'قم بإدخال المبالغ الفعلية (الجرد):' : 'Enter the actual counted amounts:', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 16)),
                const SizedBox(height: 16),
                TextField(
                  controller: _actualCashController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: isAr ? 'الكاش الفعلي في الدرج' : 'Actual Cash in Drawer',
                    border: const OutlineInputBorder(),
                    suffixText: isAr ? 'ر.س' : 'SAR',
                    prefixIcon: const Icon(Icons.money),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _actualCardController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: isAr ? 'مبيعات مدى/الشبكة الفعلية (حسب إيصال الجهاز)' : 'Actual Card Sales (from Terminal)',
                    border: const OutlineInputBorder(),
                    suffixText: isAr ? 'ر.س' : 'SAR',
                    prefixIcon: const Icon(Icons.credit_card),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _actualTransferController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: isAr ? 'التحويلات البنكية الفعلية' : 'Actual Bank Transfers',
                    border: const OutlineInputBorder(),
                    suffixText: isAr ? 'ر.س' : 'SAR',
                    prefixIcon: const Icon(Icons.account_balance),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : () {
                      // Attach expected cash before closing
                      final finalShift = shift.copyWith(expectedCash: expectedCash);
                      _closeShift(finalShift);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                    child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(isAr ? 'إغلاق الوردية وطباعة التقرير' : 'Close Shift & Print Report', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontFamily: 'Tajawal', fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color)),
          Text(value, style: TextStyle(fontFamily: 'Tajawal', fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color)),
        ],
      ),
    );
  }
}
