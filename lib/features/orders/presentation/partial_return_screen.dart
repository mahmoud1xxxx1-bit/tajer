import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../domain/order.dart';
import '../domain/order_return.dart';
import '../domain/cart_item.dart';
import '../data/order_repository.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/activity_logger.dart';
import '../../authentication/data/auth_repository.dart';
import '../../shifts/data/shift_repository.dart';

class PartialReturnScreen extends ConsumerStatefulWidget {
  final AppOrder order;

  const PartialReturnScreen({super.key, required this.order});

  @override
  ConsumerState<PartialReturnScreen> createState() =>
      _PartialReturnScreenState();
}

class _PartialReturnScreenState extends ConsumerState<PartialReturnScreen> {
  late Map<String, int> _returnQuantities;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _returnQuantities = {};
    for (var i = 0; i < widget.order.items.length; i++) {
      final item = widget.order.items[i];
      final lineId = item.lineId ?? '${widget.order.id}_$i';
      _returnQuantities[lineId] = 0;
    }
  }

  void _increment(String lineId, int maxAllowed) {
    setState(() {
      final current = _returnQuantities[lineId] ?? 0;
      if (current < maxAllowed) {
        _returnQuantities[lineId] = current + 1;
      }
    });
  }

  void _decrement(String lineId) {
    setState(() {
      final current = _returnQuantities[lineId] ?? 0;
      if (current > 0) {
        _returnQuantities[lineId] = current - 1;
      }
    });
  }

  Future<void> _submitReturn() async {
    final currentShift =
        ref.read(currentShiftProvider(widget.order.merchantId)).value;
    if (currentShift == null ||
        currentShift.status != 'open' ||
        currentShift.branchId != widget.order.branchId) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'يجب فتح وردية في نفس الفرع قبل تسجيل المرتجع.',
              style: TextStyle(fontFamily: 'Tajawal'),
            ),
          ),
        );
      }
      return;
    }

    final returnedItems = <CartItem>[];
    double returnedTotal = 0.0;
    double returnedTax = 0.0;

    for (var i = 0; i < widget.order.items.length; i++) {
      final originalItem = widget.order.items[i];
      final lineId = originalItem.lineId ?? '${widget.order.id}_$i';
      final returnQty = _returnQuantities[lineId] ?? 0;

      if (returnQty <= 0) continue;

      final unitDiscount = originalItem.quantity > 0
          ? originalItem.discountAmount / originalItem.quantity
          : 0.0;
      final discountedUnitPrice = originalItem.price - unitDiscount;
      final lineAmountBeforeExclusiveTax = discountedUnitPrice * returnQty;
      final returnedDiscount = unitDiscount * returnQty;

      // POS stores the effective tax snapshot in CartItem.taxPercentage. Going
      // through getEffectiveTax still respects TaxMode.exempt and avoids ever
      // re-applying the merchant's current tax setting to a historical sale.
      final effectiveTax = originalItem.getEffectiveTax(0.0);
      final isInclusive = originalItem.isTaxInclusive ?? true;
      double lineTax = 0.0;
      if (effectiveTax > 0) {
        lineTax = isInclusive
            ? lineAmountBeforeExclusiveTax -
                (lineAmountBeforeExclusiveTax / (1 + effectiveTax / 100))
            : lineAmountBeforeExclusiveTax * (effectiveTax / 100);
      }

      final lineRefundTotal = isInclusive
          ? lineAmountBeforeExclusiveTax
          : lineAmountBeforeExclusiveTax + lineTax;

      returnedTotal += lineRefundTotal;
      returnedTax += lineTax;

      returnedItems.add(
        originalItem.copyWith(
          quantity: returnQty,
          total: lineAmountBeforeExclusiveTax,
          lineId: lineId,
          discountAmount: returnedDiscount,
          taxPercentage: effectiveTax,
          isTaxInclusive: isInclusive,
        ),
      );
    }

    if (returnedItems.isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
      final appUser = ref.read(appUserProvider).value;
      final repository = ref.read(orderRepositoryProvider);

      final orderReturn = OrderReturn(
        id: const Uuid().v4(),
        merchantId: widget.order.merchantId,
        branchId: widget.order.branchId,
        originalOrderId: widget.order.id,
        returnedItems: returnedItems,
        returnedTotal: returnedTotal,
        returnedTax: returnedTax,
        shiftId: currentShift.id,
        employeeId: appUser?.id,
        paymentMethod: widget.order.paymentMethod ?? 'cash',
        reason: 'Partial Return',
        createdAt: DateTime.now(),
      );

      await repository.returnOrderItems(widget.order, orderReturn);

      if (appUser != null) {
        await ActivityLogger.log(
          user: appUser,
          actionType: 'إرجاع جزئي لفاتورة',
          description:
              'تم الإرجاع الجزئي للفاتورة رقم #${widget.order.queueNumber ?? widget.order.id.substring(0, 6)} بقيمة ${returnedTotal.toStringAsFixed(2)}',
          amount: returnedTotal,
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تم إرجاع الأصناف بنجاح',
              style: TextStyle(fontFamily: 'Tajawal'),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'خطأ: $e',
              style: const TextStyle(fontFamily: 'Tajawal'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(currencyProvider);
    final theme = Theme.of(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    int totalReturnedCount = 0;
    for (final q in _returnQuantities.values) {
      totalReturnedCount += q;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isAr ? 'إرجاع جزئي للفاتورة' : 'Partial Return',
          style: const TextStyle(
            fontFamily: 'Tajawal',
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isSubmitting
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: widget.order.items.length,
              itemBuilder: (context, index) {
                final item = widget.order.items[index];
                final lineId = item.lineId ?? '${widget.order.id}_$index';
                final alreadyReturned =
                    widget.order.returnedQuantities[lineId] ?? 0;
                final maxAllowed = item.quantity - alreadyReturned;
                final currentlyReturning = _returnQuantities[lineId] ?? 0;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.productName,
                                style: const TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${isAr ? 'المتاح للإرجاع' : 'Available to return'}: $maxAllowed',
                                style: TextStyle(
                                  color: maxAllowed > 0
                                      ? Colors.green
                                      : Colors.grey,
                                  fontFamily: 'Tajawal',
                                ),
                              ),
                              if (alreadyReturned > 0)
                                Text(
                                  '${isAr ? 'تم إرجاعه مسبقاً' : 'Already returned'}: $alreadyReturned',
                                  style: const TextStyle(
                                    color: Colors.orange,
                                    fontFamily: 'Tajawal',
                                    fontSize: 12,
                                  ),
                                ),
                              Text(
                                '${(item.price * currentlyReturning).toStringAsFixed(2)} $currency',
                                style: const TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (maxAllowed > 0)
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.remove_circle_outline,
                                  color: Colors.red,
                                ),
                                onPressed: () => _decrement(lineId),
                              ),
                              Text(
                                '$currentlyReturning',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.add_circle_outline,
                                  color: Colors.green,
                                ),
                                onPressed: () => _increment(lineId, maxAllowed),
                              ),
                            ],
                          )
                        else
                          Text(
                            isAr ? 'مسترجع بالكامل' : 'Fully Returned',
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              color: Colors.grey,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
      bottomNavigationBar: totalReturnedCount > 0 && !_isSubmitting
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: theme.colorScheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _submitReturn,
                  child: Text(
                    isAr ? 'تأكيد الإرجاع' : 'Confirm Return',
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}
