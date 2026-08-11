import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/effective_merchant.dart';
import '../../authentication/data/auth_repository.dart';
import '../../branches/presentation/branch_context.dart';
import '../../products/data/product_repository.dart';
import '../../products/data/raw_material_repository.dart';
import '../../shifts/data/shift_repository.dart';
import '../../stocktake/data/stocktake_repository.dart';
import '../data/action_center_repository.dart';
import '../../products/domain/product.dart';
import '../../products/domain/raw_material.dart';

Future<void> _logAlert(Ref ref, String type, String severity, String sourceType, String sourceId, String message, String branchId, {Map<String, dynamic>? extraMetadata}) async {
  final appUser = ref.read(appUserProvider).value;
  print('appUser: $appUser'); if (appUser == null) return;
  final merchantId = currentEffectiveMerchantId(appUser);

  await ref.read(actionCenterRepositoryProvider).logAlert(
    merchantId: merchantId,
    branchId: branchId,
    type: type,
    severity: severity,
    sourceType: sourceType,
    sourceId: sourceId,
    metadata: {'message': message, if (extraMetadata != null) ...extraMetadata},
  );
}

Future<void> _resolveAlert(Ref ref, String type, String sourceType, String sourceId, String branchId) async {
  final appUser = ref.read(appUserProvider).value;
  print('appUser: $appUser'); if (appUser == null) return;
  final merchantId = currentEffectiveMerchantId(appUser);

  final fingerprint = '${branchId}_${type}_${sourceType}_$sourceId'.replaceAll('/', '_');
  await ref.read(actionCenterRepositoryProvider).resolveAlert(merchantId, fingerprint);
}

void evaluateProducts(Ref ref, List<Product> products, String branchId) {
  for (final p in products) {
    if (!p.isArchived) {
      if (p.quantity <= 0) {
        _logAlert(ref, 'out_of_stock', 'high', 'product', p.id, '${p.name} is out of stock.', branchId, extraMetadata: {'productName': p.name});
      } else if (p.lowStockThreshold > 0 && p.quantity <= p.lowStockThreshold) {
        _logAlert(ref, 'low_stock', 'medium', 'product', p.id, '${p.name} is running low.', branchId, extraMetadata: {'productName': p.name});
        _resolveAlert(ref, 'out_of_stock', 'product', p.id, branchId);
      } else {
        _resolveAlert(ref, 'out_of_stock', 'product', p.id, branchId);
        _resolveAlert(ref, 'low_stock', 'product', p.id, branchId);
      }

      if (p.lowStockThreshold > 0) {
        if (p.targetQuantity == null || p.preferredSupplierId == null) {
          _logAlert(ref, 'reorder_configuration_required', 'medium', 'product', p.id, 'Configure target quantity and supplier for ${p.name}.', branchId, extraMetadata: {'productName': p.name});
        } else {
          _resolveAlert(ref, 'reorder_configuration_required', 'product', p.id, branchId);
          if (p.quantity <= p.lowStockThreshold) {
            _logAlert(ref, 'reorder_needed', 'high', 'product', p.id, 'Generate PO for ${p.name}.', branchId, extraMetadata: {'productName': p.name});
          } else {
            _resolveAlert(ref, 'reorder_needed', 'product', p.id, branchId);
          }
        }
      } else {
        _resolveAlert(ref, 'reorder_configuration_required', 'product', p.id, branchId);
        _resolveAlert(ref, 'reorder_needed', 'product', p.id, branchId);
      }
    }
  }
}

void evaluateRawMaterials(Ref ref, List<RawMaterial> materials, String branchId) {
  for (final m in materials) {
    if (!m.isArchived) {
      if (m.quantity <= 0) {
        _logAlert(ref, 'out_of_stock', 'high', 'raw_material', m.id, '${m.name} is out of stock.', branchId, extraMetadata: {'rawMaterialName': m.name});
      } else if ((m.lowStockThreshold ?? 0) > 0 && m.quantity <= m.lowStockThreshold!) {
        _logAlert(ref, 'low_stock', 'medium', 'raw_material', m.id, '${m.name} is running low.', branchId, extraMetadata: {'rawMaterialName': m.name});
        _resolveAlert(ref, 'out_of_stock', 'raw_material', m.id, branchId);
      } else {
        _resolveAlert(ref, 'out_of_stock', 'raw_material', m.id, branchId);
        _resolveAlert(ref, 'low_stock', 'raw_material', m.id, branchId);
      }

      final lowStock = m.lowStockThreshold ?? 0;
      if (lowStock > 0) {
        if (m.targetQuantity == null || m.preferredSupplierId == null) {
          _logAlert(ref, 'reorder_configuration_required', 'medium', 'raw_material', m.id, 'Configure target quantity and supplier for ${m.name}.', branchId, extraMetadata: {'rawMaterialName': m.name});
        } else {
          _resolveAlert(ref, 'reorder_configuration_required', 'raw_material', m.id, branchId);
          if (m.quantity <= lowStock) {
            _logAlert(ref, 'reorder_needed', 'high', 'raw_material', m.id, 'Generate PO for ${m.name}.', branchId, extraMetadata: {'rawMaterialName': m.name});
          } else {
            _resolveAlert(ref, 'reorder_needed', 'raw_material', m.id, branchId);
          }
        }
      } else {
        _resolveAlert(ref, 'reorder_configuration_required', 'raw_material', m.id, branchId);
        _resolveAlert(ref, 'reorder_needed', 'raw_material', m.id, branchId);
      }
    }
  }
}

void _evaluateShifts(Ref ref, List<dynamic> shifts, String branchId) {
  for (final shift in shifts) {
    if (shift.status == 'open') {
      final hoursOpen = DateTime.now().difference(shift.startTime).inHours;
      if (hoursOpen >= 12) {
        _logAlert(ref, 'long_open_shift', 'medium', 'shift', shift.id, 'Shift ${shift.id} has been open for >12 hours.', branchId);
      } else {
        _resolveAlert(ref, 'long_open_shift', 'shift', shift.id, branchId);
      }
    } else if (shift.status == 'closed' || shift.status == 'ended') {
      _resolveAlert(ref, 'long_open_shift', 'shift', shift.id, branchId);
      
      final expected = shift.expectedCash ?? 0.0;
      final actual = shift.actualCash ?? 0.0;
      if ((expected - actual).abs() > 0.01) {
        _logAlert(ref, 'shift_cash_discrepancy', 'high', 'shift', shift.id, 'Discrepancy of ${(actual - expected).toStringAsFixed(2)}', branchId);
      } else {
        _resolveAlert(ref, 'shift_cash_discrepancy', 'shift', shift.id, branchId);
      }
    }
  }
}

void _evaluateStocktakes(Ref ref, List<dynamic> stocktakes, String branchId) {
  for (final s in stocktakes) {
    if (s.status == 'review_required' || s.status == 'conflict') {
      _logAlert(ref, 'stocktake_conflict', 'high', 'stocktake', s.id, 'Stocktake requires review.', branchId);
    } else {
      _resolveAlert(ref, 'stocktake_conflict', 'stocktake', s.id, branchId);
    }
  }
}

final actionCenterEvaluatorProvider = Provider.autoDispose((ref) {
  final branchId = ref.watch(selectedBranchIdProvider);
  final appUser = ref.watch(appUserProvider).value;
  if (branchId.isNotEmpty && appUser != null) {
    final merchantId = currentEffectiveMerchantId(appUser);
    ref.listen(productsStreamProvider, (previous, next) {
      final products = next.value;
      if (products != null) evaluateProducts(ref, products, branchId);
    });
    ref.listen(rawMaterialsStreamProvider(merchantId), (previous, next) {
      final materials = next.value;
      if (materials != null) evaluateRawMaterials(ref, materials, branchId);
    });
    ref.listen(shiftsStreamProvider, (previous, next) {
      final shifts = next.value;
      if (shifts != null) _evaluateShifts(ref, shifts, branchId);
    });
    ref.listen(stocktakeSessionsProvider(branchId), (previous, next) {
      final stocktakes = next.value;
      if (stocktakes != null) _evaluateStocktakes(ref, stocktakes, branchId);
    });
  }
  return true;
});
