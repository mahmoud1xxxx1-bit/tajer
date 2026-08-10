import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../branches/data/branch_inventory_repository.dart';
import '../domain/purchase_invoice.dart';
import 'package:tajer/features/authentication/application/session_identity.dart';

final purchaseInvoiceRepositoryProvider = Provider<PurchaseInvoiceRepository>((ref) {
  final firestore = FirebaseFirestore.instance;
  final session = ref.watch(sessionIdentityProvider);
  if (session == null) {
    throw Exception('No session identity available');
  }
  return PurchaseInvoiceRepository(firestore, session.effectiveMerchantId);
});

class PurchaseInvoiceRepository {
  final FirebaseFirestore _firestore;
  final String _merchantId;

  PurchaseInvoiceRepository(this._firestore, this._merchantId);

  CollectionReference<Map<String, dynamic>> get _invoicesRef => _firestore
      .collection('merchants')
      .doc(_merchantId)
      .collection('purchase_invoices');

  CollectionReference<Map<String, dynamic>> get _suppliersRef =>
      _firestore.collection('merchants').doc(_merchantId).collection('suppliers');

  CollectionReference<Map<String, dynamic>> get _expensesRef =>
      _firestore.collection('merchants').doc(_merchantId).collection('expenses');

  Future<PurchaseInvoice> createPurchaseInvoice({
    required String branchId,
    required String supplierId,
    required String supplierName,
    required String invoiceNumber,
    required List<PurchaseInvoiceItem> items,
    required double totalAmount,
    required double amountPaid,
    required String paymentMethod,
    required bool isFromShiftDrawer,
    String? shiftId,
    String? creatorId,
    String? creatorName,
  }) async {
    if (branchId.trim().isEmpty) {
      throw Exception('Branch ID is required.');
    }
    if (totalAmount <= 0 && items.isEmpty) {
      throw Exception('Cannot create an empty purchase invoice.');
    }
    if (amountPaid > totalAmount) {
      throw Exception('Amount paid cannot exceed total invoice amount.');
    }

    final invoiceId = const Uuid().v4();
    final occurredAt = DateTime.now();
    final needsOpenShift = paymentMethod == 'cash' && isFromShiftDrawer && amountPaid > 0;
    
    final supplierRef = _suppliersRef.doc(supplierId);
    final purchaseTxId = const Uuid().v4();
    final supplierPurchaseTxRef = supplierRef.collection('transactions').doc(purchaseTxId);
    
    String? paymentTxId;
    DocumentReference<Map<String, dynamic>>? supplierPaymentTxRef;
    String? expenseId;
    DocumentReference<Map<String, dynamic>>? expenseRef;
    
    if (amountPaid > 0) {
      paymentTxId = const Uuid().v4();
      supplierPaymentTxRef = supplierRef.collection('transactions').doc(paymentTxId);
      expenseId = const Uuid().v4();
      expenseRef = _expensesRef.doc(expenseId);
    }

    final shiftRef = needsOpenShift && shiftId != null && shiftId.isNotEmpty
        ? _firestore.collection('shifts').doc(shiftId)
        : null;

    final invoiceRef = _invoicesRef.doc(invoiceId);

    // Pre-calculate inventory doc references and legacy mutations
    final branchInventoryRepo = BranchInventoryRepository(_firestore, _merchantId);
    final inventoryRefs = <String, DocumentReference<Map<String, dynamic>>>{};
    final inventoryLogs = <String, DocumentReference<Map<String, dynamic>>>{};
    final mutations = <BranchInventoryMutation>[];

    for (final item in items) {
      final key = branchInventoryRepo.docId(branchId, item.itemType, item.itemId);
      inventoryRefs[key] = branchInventoryRepo.ref.doc(key);
      inventoryLogs[key] = _firestore
          .collection('merchants')
          .doc(_merchantId)
          .collection('inventory_logs')
          .doc();
    }

    final createdInvoice = await _firestore.runTransaction<PurchaseInvoice>((tx) async {
      // 1. Read Shift (if needed)
      if (needsOpenShift) {
        if (shiftRef == null) {
          throw Exception('A valid shift is required for cash payments from the drawer.');
        }
        final shiftSnapshot = await tx.get(shiftRef);
        if (!shiftSnapshot.exists || shiftSnapshot.data() == null) {
          throw Exception('The specified shift does not exist.');
        }
        final shiftData = shiftSnapshot.data()!;
        final shiftBranchId = shiftData['branchId']?.toString() ?? 'main';
        if (shiftBranchId != branchId ||
            shiftData['status']?.toString() != 'open' ||
            shiftData['endTime'] != null) {
          throw Exception('The shift must be active and belong to the correct branch.');
        }
      }

      // 2. Read Supplier
      final supplierSnapshot = await tx.get(supplierRef);
      if (!supplierSnapshot.exists || supplierSnapshot.data() == null) {
        throw Exception('Supplier does not exist.');
      }

      // 3. Read existing inventory items (for logs/legacy fallback)
      final existingInventory = <String, Map<String, dynamic>>{};
      for (final key in inventoryRefs.keys) {
        final snap = await tx.get(inventoryRefs[key]!);
        if (snap.exists && snap.data() != null) {
          existingInventory[key] = snap.data()!;
        }
      }

      for (final item in items) {
        final key = branchInventoryRepo.docId(branchId, item.itemType, item.itemId);
        mutations.add(
          BranchInventoryMutation(
            itemType: item.itemType,
            itemId: item.itemId,
            delta: item.quantity,
            legacyMainQuantity: (existingInventory[key]?['quantity'] as num?)?.toDouble() ?? 0.0,
          ),
        );
      }

      // WRITE OPERATIONS
      
      // A. Increase Debt for Purchase
      tx.update(supplierRef, {
        'totalDebt': FieldValue.increment(totalAmount),
      });

      tx.set(supplierPurchaseTxRef, {
        'id': purchaseTxId,
        'supplierId': supplierId,
        'merchantId': _merchantId,
        'branchId': branchId,
        'amount': totalAmount,
        'type': 'purchase',
        'description': 'فاتورة مشتريات رقم $invoiceNumber',
        'date': Timestamp.fromDate(occurredAt),
        'createdAt': Timestamp.fromDate(occurredAt),
        'isCancelled': false,
        'purchaseInvoiceId': invoiceId,
      });

      // B. Process Payment (if any)
      if (amountPaid > 0 && supplierPaymentTxRef != null && expenseRef != null) {
        tx.update(supplierRef, {
          'totalDebt': FieldValue.increment(-amountPaid),
        });

        tx.set(supplierPaymentTxRef, {
          'id': paymentTxId,
          'supplierId': supplierId,
          'merchantId': _merchantId,
          'branchId': branchId,
          'expenseId': expenseId,
          'amount': amountPaid,
          'type': 'payment',
          'paymentMethod': paymentMethod,
          'description':
              'دفعة سداد ديون للمورد${paymentMethod == 'cash' ? (isFromShiftDrawer ? ' (من الدرج)' : ' (خارج الدرج)') : ''}',
          'date': Timestamp.fromDate(occurredAt),
          'createdAt': Timestamp.fromDate(occurredAt),
          'isCancelled': false,
          'purchaseInvoiceId': invoiceId,
        });

        tx.set(expenseRef, {
          'id': expenseId,
          'merchantId': _merchantId,
          'branchId': branchId,
          'shiftId': shiftId,
          'title': 'دفعة سداد ديون للمورد: $supplierName',
          'amount': amountPaid,
          'category': null,
          'notes': 'فاتورة رقم $invoiceNumber',
          'creatorId': creatorId,
          'creatorName': creatorName ?? 'المدير',
          'isSupplierPayment': true,
          'paymentMethod': paymentMethod,
          'date': Timestamp.fromDate(occurredAt),
          'createdAt': Timestamp.fromDate(occurredAt),
          'isFromShiftDrawer': isFromShiftDrawer,
          'isCancelled': false,
          'supplierTransactionId': paymentTxId,
        });

        if (needsOpenShift && shiftRef != null) {
          tx.update(shiftRef, {
            'cashSales': FieldValue.increment(-amountPaid),
          });
        } else if (['card', 'mada', 'apple_pay'].contains(paymentMethod) && shiftRef != null) {
            // Note: Current SupplierRepository does not decrement cardTotal on expenses, 
            // but if we are following strict drawer integrity, it might.
            // Tajer CURRENT behavior: Expenses do NOT decrement cardTotal in shifts. 
            // They are tracked independently via expense queries. So we do nothing for card.
        }
      }

      // C. Update Inventory
      for (final mutation in mutations) {
        final key = branchInventoryRepo.docId(branchId, mutation.itemType, mutation.itemId);
        tx.set(
          inventoryRefs[key]!,
          {
            'merchantId': _merchantId,
            'branchId': branchId,
            'type': mutation.itemType,
            'itemId': mutation.itemId,
            'quantity': FieldValue.increment(mutation.delta),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        final itemName = items.firstWhere((i) => i.itemId == mutation.itemId).itemName;

        tx.set(inventoryLogs[key]!, {
          'merchantId': _merchantId,
          'branchId': branchId,
          'type': mutation.itemType,
          'itemId': mutation.itemId,
          'itemName': itemName,
          'change': mutation.delta,
          'previousQuantity': mutation.legacyMainQuantity,
          'newQuantity': mutation.legacyMainQuantity + mutation.delta,
          'reason': 'استلام بضاعة - فاتورة $invoiceNumber',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // D. Save Invoice
      final invoice = PurchaseInvoice(
        id: invoiceId,
        merchantId: _merchantId,
        branchId: branchId,
        supplierId: supplierId,
        supplierName: supplierName,
        invoiceNumber: invoiceNumber,
        items: items,
        totalAmount: totalAmount,
        amountPaid: amountPaid,
        paymentMethod: paymentMethod,
        isFromShiftDrawer: isFromShiftDrawer,
        shiftId: shiftId,
        expenseId: expenseId,
        supplierTransactionId: paymentTxId,
        creatorId: creatorId,
        creatorName: creatorName,
        createdAt: occurredAt,
      );

      tx.set(invoiceRef, invoice.toJson());

      return invoice;
    });

    return createdInvoice;
  }

  Future<void> reversePurchaseInvoice({
    required String invoiceId,
  }) async {
    final invoiceRef = _invoicesRef.doc(invoiceId);
    
    final invoiceSnapshotFirst = await invoiceRef.get();
    if (!invoiceSnapshotFirst.exists || invoiceSnapshotFirst.data() == null) {
      throw Exception('Invoice does not exist.');
    }
    
    final supplierId = invoiceSnapshotFirst.data()!['supplierId']?.toString() ?? '';
    if (supplierId.isEmpty) throw Exception('Missing supplier ID on invoice.');
    
    final supplierRef = _suppliersRef.doc(supplierId);
    
    final purchaseTxQuery = await supplierRef.collection('transactions')
        .where('purchaseInvoiceId', isEqualTo: invoiceId)
        .where('type', isEqualTo: 'purchase')
        .get();
        
    final purchaseTxRef = purchaseTxQuery.docs.isNotEmpty 
        ? purchaseTxQuery.docs.first.reference 
        : null;

    await _firestore.runTransaction((tx) async {
      final invoiceSnapshot = await tx.get(invoiceRef);
      if (!invoiceSnapshot.exists || invoiceSnapshot.data() == null) {
        throw Exception('Invoice does not exist.');
      }
      final invoiceData = invoiceSnapshot.data()!;
      if (invoiceData['isCancelled'] == true) {
        throw Exception('Invoice is already cancelled.');
      }

      final branchId = invoiceData['branchId']?.toString() ?? '';
      final totalAmount = (invoiceData['totalAmount'] as num?)?.toDouble() ?? 0.0;
      final amountPaid = (invoiceData['amountPaid'] as num?)?.toDouble() ?? 0.0;
      final expenseId = invoiceData['expenseId']?.toString();
      final supplierPaymentTxId = invoiceData['supplierTransactionId']?.toString();
      final paymentMethod = invoiceData['paymentMethod']?.toString();
      final isFromShiftDrawer = invoiceData['isFromShiftDrawer'] == true;
      final shiftId = invoiceData['shiftId']?.toString();

      if (branchId.isEmpty) {
        throw Exception('Missing branch ID on invoice.');
      }

      final supplierSnapshot = await tx.get(supplierRef);
      if (!supplierSnapshot.exists) {
        throw Exception('Supplier does not exist.');
      }

      // Check if inventory can be safely reversed
      final items = (invoiceData['items'] as List<dynamic>?) ?? [];
      final branchInventoryRepo = BranchInventoryRepository(_firestore, _merchantId);
      final inventoryRefs = <String, DocumentReference<Map<String, dynamic>>>{};
      final existingInventory = <String, Map<String, dynamic>>{};

      for (final itemRaw in items) {
        final itemMap = Map<String, dynamic>.from(itemRaw as Map);
        final itemType = itemMap['itemType']?.toString() ?? '';
        final itemId = itemMap['itemId']?.toString() ?? '';
        final key = branchInventoryRepo.docId(branchId, itemType, itemId);
        inventoryRefs[key] = branchInventoryRepo.ref.doc(key);
      }

      for (final key in inventoryRefs.keys) {
        final snap = await tx.get(inventoryRefs[key]!);
        if (snap.exists && snap.data() != null) {
          existingInventory[key] = snap.data()!;
        } else {
          existingInventory[key] = {'quantity': 0.0};
        }
      }

      for (final itemRaw in items) {
        final itemMap = Map<String, dynamic>.from(itemRaw as Map);
        final itemType = itemMap['itemType']?.toString() ?? '';
        final itemId = itemMap['itemId']?.toString() ?? '';
        final delta = (itemMap['quantity'] as num?)?.toDouble() ?? 0.0;
        final key = branchInventoryRepo.docId(branchId, itemType, itemId);
        
        final currentQty = (existingInventory[key]?['quantity'] as num?)?.toDouble() ?? 0.0;
        if (currentQty < delta) {
          throw Exception('Inventory cannot be safely reversed. Stock for $itemId is lower than invoice quantity.');
        }
      }

      // Reverse Supplier Debt
      tx.update(supplierRef, {
        'totalDebt': FieldValue.increment(-totalAmount + amountPaid),
        'branchDebts.$branchId': FieldValue.increment(-totalAmount + amountPaid),
      });
      
      // Update inventory (Reverse additions)
      for (final itemRaw in items) {
        final itemMap = Map<String, dynamic>.from(itemRaw as Map);
        final itemType = itemMap['itemType']?.toString() ?? '';
        final itemId = itemMap['itemId']?.toString() ?? '';
        final delta = (itemMap['quantity'] as num?)?.toDouble() ?? 0.0;
        final key = branchInventoryRepo.docId(branchId, itemType, itemId);
        
        tx.update(inventoryRefs[key]!, {
          'quantity': FieldValue.increment(-delta),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        final itemName = itemMap['itemName']?.toString() ?? '';
        final currentQty = (existingInventory[key]?['quantity'] as num?)?.toDouble() ?? 0.0;
        
        final logRef = _firestore
            .collection('merchants')
            .doc(_merchantId)
            .collection('inventory_logs')
            .doc();
            
        tx.set(logRef, {
          'merchantId': _merchantId,
          'branchId': branchId,
          'type': itemType,
          'itemId': itemId,
          'itemName': itemName,
          'change': -delta,
          'previousQuantity': currentQty,
          'newQuantity': currentQty - delta,
          'reason': 'إلغاء فاتورة مشتريات',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // Reverse shift cash if applicable
      if (amountPaid > 0 && paymentMethod == 'cash' && isFromShiftDrawer && shiftId != null && shiftId.isNotEmpty) {
        final shiftRef = _firestore.collection('shifts').doc(shiftId);
        final shiftSnapshot = await tx.get(shiftRef);
        if (shiftSnapshot.exists && shiftSnapshot.data()?['status'] == 'open') {
          tx.update(shiftRef, {
            'cashSales': FieldValue.increment(amountPaid),
          });
        }
      }

      // Cancel related documents
      tx.update(invoiceRef, {'isCancelled': true});
      
      if (purchaseTxRef != null) {
        tx.update(purchaseTxRef, {'isCancelled': true});
      }
      
      if (supplierPaymentTxId != null && supplierPaymentTxId.isNotEmpty) {
        final paymentTxRef = supplierRef.collection('transactions').doc(supplierPaymentTxId);
        tx.update(paymentTxRef, {'isCancelled': true});
      }
      
      if (expenseId != null && expenseId.isNotEmpty) {
        final expenseRef = _firestore.collection('merchants').doc(_merchantId).collection('expenses').doc(expenseId);
        tx.update(expenseRef, {'isCancelled': true});
      }
    });
  }
}
