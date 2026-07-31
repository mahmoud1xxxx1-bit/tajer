import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/shift.dart';
import '../data/shift_repository.dart';
import '../../authentication/data/auth_repository.dart';
import '../../../core/services/printer_service.dart';
import '../../../core/providers/store_profile_provider.dart';

class EndShiftScreen extends ConsumerStatefulWidget {
  const EndShiftScreen({super.key});

  @override
  ConsumerState<EndShiftScreen> createState() => _EndShiftScreenState();
}

class _EndShiftScreenState extends ConsumerState<EndShiftScreen> {
  final _actualCashController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _actualCashController.dispose();
    super.dispose();
  }

  Future<void> _closeShift(Shift shift) async {
    final actualCash = double.tryParse(_actualCashController.text);
    if (actualCash == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء إدخال مبلغ صحيح', style: TextStyle(fontFamily: 'Tajawal'))));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final updatedShift = shift.copyWith(
        endTime: DateTime.now(),
        actualCash: actualCash,
        status: 'closed',
      );
      
      await ref.read(shiftRepositoryProvider).closeShift(updatedShift);
      
      // Print Z-Report
      final storeProfile = ref.read(storeProfileProvider).value;
      try {
        await PrinterService.printZReport(updatedShift, 'ر.س', storeProfile: storeProfile);
      } catch (e) {
        // Just show a snackbar if printing fails, but shift is closed
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم الإغلاق ولكن تعذرت الطباعة: $e', style: TextStyle(fontFamily: 'Tajawal'))));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إغلاق الوردية بنجاح', style: TextStyle(fontFamily: 'Tajawal'))));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e', style: TextStyle(fontFamily: 'Tajawal'))));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authRepositoryProvider).value;
    final merchantId = user?.merchantId ?? user?.id;
    final shiftAsync = ref.watch(currentShiftProvider(merchantId ?? ''));

    return Scaffold(
      appBar: AppBar(
        title: const Text('إغلاق الوردية وجرد الصندوق', style: TextStyle(fontFamily: 'Tajawal')),
      ),
      body: shiftAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (shift) {
          if (shift == null) {
            return const Center(
              child: Text('لا توجد وردية مفتوحة حالياً', style: TextStyle(fontFamily: 'Tajawal', fontSize: 18)),
            );
          }

          // Expected Cash = Start Cash + Cash Sales
          final expectedCash = shift.startCash + (shift.cashSales ?? 0.0);

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('معلومات الوردية', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 18, color: Theme.of(context).primaryColor)),
                        const SizedBox(height: 16),
                        _buildRow('الموظف:', shift.employeeName),
                        _buildRow('وقت البدء:', shift.startTime.toString()),
                        _buildRow('العهدة الافتتاحية:', '${shift.startCash.toStringAsFixed(2)} ر.س'),
                        _buildRow('مبيعات مدى/تحويل:', '${((shift.cardTotal ?? 0) + (shift.transferTotal ?? 0)).toStringAsFixed(2)} ر.س'),
                        const Divider(),
                        _buildRow('المبيعات النقدية:', '${(shift.cashSales ?? 0.0).toStringAsFixed(2)} ر.س'),
                        _buildRow('الكاش المتوقع في الدرج:', '${expectedCash.toStringAsFixed(2)} ر.س', isBold: true),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                const Text('قم بعدّ الكاش الموجود في الدرج الآن وأدخله أدناه:', style: TextStyle(fontFamily: 'Tajawal', fontSize: 16)),
                const SizedBox(height: 16),
                TextField(
                  controller: _actualCashController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    labelText: 'الكاش الفعلي في الدرج',
                    border: OutlineInputBorder(),
                    suffixText: 'ر.س',
                    prefixIcon: Icon(Icons.money),
                  ),
                ),
                const Spacer(),
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
                      : const Text('إغلاق الوردية وطباعة التقرير', style: TextStyle(fontFamily: 'Tajawal', fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontFamily: 'Tajawal', fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(fontFamily: 'Tajawal', fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}
