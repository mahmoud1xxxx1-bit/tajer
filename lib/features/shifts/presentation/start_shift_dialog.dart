import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../domain/shift.dart';
import '../data/shift_repository.dart';
import '../../authentication/data/auth_repository.dart';

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
    final user = ref.read(authRepositoryProvider).value;
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      final shift = Shift(
        id: const Uuid().v4(),
        merchantId: user.merchantId ?? user.id,
        employeeId: user.id,
        employeeName: user.name,
        startTime: DateTime.now(),
        startCash: cash,
        status: 'open',
      );
      await ref.read(shiftRepositoryProvider).openShift(shift);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e', style: TextStyle(fontFamily: 'Tajawal'))));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('بداية وردية جديدة', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('الرجاء إدخال مبلغ العهدة الافتتاحية (الكاش الموجود في الدرج الآن):', style: TextStyle(fontFamily: 'Tajawal')),
          const SizedBox(height: 16),
          TextField(
            controller: _cashController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'مبلغ العهدة',
              border: OutlineInputBorder(),
              suffixText: 'ر.س',
            ),
          ),
        ],
      ),
      actions: [
        _isLoading 
          ? const CircularProgressIndicator()
          : ElevatedButton(
              onPressed: _startShift,
              child: const Text('فتح الوردية', style: TextStyle(fontFamily: 'Tajawal')),
            ),
      ],
    );
  }
}
