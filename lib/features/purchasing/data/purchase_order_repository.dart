import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/effective_merchant.dart';
import '../../authentication/data/auth_repository.dart';
import '../../suppliers/data/purchase_invoice_repository.dart';
import '../../suppliers/domain/purchase_invoice.dart';
import '../domain/purchase_order.dart';

class PurchaseOrderRepository {
  final FirebaseFirestore _firestore;

  PurchaseOrderRepository(this._firestore);

  Stream<List<PurchaseOrder>> watchPurchaseOrders(String merchantId, String branchId) {
    return _firestore
        .collection('merchants')
        .doc(merchantId)
        .collection('purchase_orders')
        .where('branchId', isEqualTo: branchId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return PurchaseOrder.fromJson(data);
            }).toList());
  }

  Future<void> createPurchaseOrder(PurchaseOrder order) async {
    final ref = _firestore
        .collection('merchants')
        .doc(order.merchantId)
        .collection('purchase_orders')
        .doc();
    
    final newOrder = order.copyWith(id: ref.id);
    await ref.set(newOrder.toJson());
  }

  Future<void> updateOrderStatus(String merchantId, String orderId, String status) async {
    await _firestore
        .collection('merchants')
        .doc(merchantId)
        .collection('purchase_orders')
        .doc(orderId)
        .update({'status': status});
  }

  Future<void> receiveGoods({
    required PurchaseOrder order,
    required List<PurchaseOrderLine> receiptLines,
    required String actorUid,
    required String actorName,
    required String operationId,
  }) async {
    if (order.status == 'cancelled' || order.status == 'received') {
      throw Exception('Cannot receive on a cancelled or fully received purchase order.');
    }

    final orderRef = _firestore
        .collection('merchants')
        .doc(order.merchantId)
        .collection('purchase_orders')
        .doc(order.id);

    final invoiceRepo = PurchaseInvoiceRepository(_firestore, order.merchantId);

    List<PurchaseInvoiceItem> newInvoiceLines = [];
    double totalInvoiceCost = 0;
    
    // We compute the requested invoice based on the client's known state.
    // If the server state differs (e.g. concurrent receipt), the transaction will abort.
    for (var receiptLine in receiptLines) {
      if (receiptLine.receivedQuantity <= 0) continue;

      final idx = order.lines.indexWhere((l) => l.id == receiptLine.id);
      if (idx == -1) continue;

      final currentLine = order.lines[idx];
      final cost = receiptLine.unitCost ?? currentLine.unitCost ?? 0;
      
      newInvoiceLines.add(PurchaseInvoiceItem(
        itemId: currentLine.itemId,
        itemName: currentLine.itemNameSnapshot,
        itemType: currentLine.itemType,
        quantity: receiptLine.receivedQuantity,
        unitCost: cost,
        totalCost: receiptLine.receivedQuantity * cost,
      ));

      totalInvoiceCost += (receiptLine.receivedQuantity * cost);
    }

    if (newInvoiceLines.isEmpty) return;

    await invoiceRepo.createPurchaseInvoice(
      branchId: order.branchId,
      supplierId: order.supplierId,
      supplierName: 'Supplier', // Could fetch proper name
      invoiceNumber: 'PO-${order.id}-$operationId',
      items: newInvoiceLines,
      totalAmount: totalInvoiceCost,
      amountPaid: 0,
      paymentMethod: 'credit',
      isFromShiftDrawer: false,
      creatorId: actorUid,
      creatorName: actorName,
      onTransactionRead: (tx, invoiceId) async {
        final snap = await tx.get(orderRef);
        if (!snap.exists) throw Exception('Purchase order not found.');
        final data = snap.data()!;
        
        // 1. Idempotency Check
        final pastOps = List<String>.from(data['receiptOperations'] ?? []);
        if (pastOps.contains(operationId)) {
          // Silent abort for true idempotency, or throw to cancel TX
          throw Exception('IDEMPOTENT_RETRY_ABORT'); 
        }

        if (data['status'] == 'cancelled' || data['status'] == 'received') {
          throw Exception('Cannot receive on a cancelled or fully received purchase order.');
        }

        // 2. Concurrency Check & Line Updates
        final currentLines = (data['lines'] as List<dynamic>).map((e) => PurchaseOrderLine.fromJson(e)).toList();
        bool allFullyReceived = true;
        
        for (var reqLine in receiptLines) {
          if (reqLine.receivedQuantity <= 0) continue;
          
          final idx = currentLines.indexWhere((l) => l.id == reqLine.id);
          if (idx == -1) throw Exception('Line not found in current PO state.');
          
          final current = currentLines[idx];
          final remaining = current.orderedQuantity - current.receivedQuantity;
          
          if (reqLine.receivedQuantity > remaining) {
             throw Exception('Concurrency error: requested quantity exceeds remaining ordered quantity.');
          }
          
          currentLines[idx] = current.copyWith(
            receivedQuantity: current.receivedQuantity + reqLine.receivedQuantity
          );
        }

        for (var l in currentLines) {
          if (l.receivedQuantity < l.orderedQuantity) {
            allFullyReceived = false;
            break;
          }
        }

        pastOps.add(operationId);

        tx.update(orderRef, {
          'status': allFullyReceived ? 'received' : 'partiallyReceived',
          'lines': currentLines.map((e) => e.toJson()).toList(),
          'receiptOperations': pastOps,
        });
      },
    ).catchError((e) {
      if (e.toString().contains('IDEMPOTENT_RETRY_ABORT')) {
        // Suppress the error on the client side, as the operation already succeeded previously.
        return PurchaseInvoice(
          id: '', merchantId: '', branchId: '', supplierId: '', supplierName: '', 
          invoiceNumber: '', items: [], totalAmount: 0, amountPaid: 0, 
          paymentMethod: '', isFromShiftDrawer: false, createdAt: DateTime.now()
        );
      }
      throw e;
    });
  }
}

final purchaseOrderRepositoryProvider = Provider((ref) {
  return PurchaseOrderRepository(FirebaseFirestore.instance);
});

final purchaseOrdersProvider = StreamProvider.family<List<PurchaseOrder>, String>((ref, branchId) {
  final appUser = ref.watch(appUserProvider).value;
  if (appUser == null) return Stream.value([]);
  final merchantId = currentEffectiveMerchantId(appUser);
  return ref.watch(purchaseOrderRepositoryProvider).watchPurchaseOrders(merchantId, branchId);
});
