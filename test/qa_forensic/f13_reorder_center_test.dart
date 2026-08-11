import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:tajer/features/purchasing/data/purchase_order_repository.dart';
import 'package:tajer/features/purchasing/domain/purchase_order.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  group('F13 Purchase Order Production Logic Tests', () {
    late FakeFirebaseFirestore firestore;
    late PurchaseOrderRepository repo;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repo = PurchaseOrderRepository(firestore);
    });

    test('PurchaseOrder model persists draft lifecycle', () async {
      final order = PurchaseOrder(
        id: '',
        merchantId: 'm1',
        branchId: 'b1',
        supplierId: 's1',
        status: 'draft',
        createdAt: DateTime.now(),
        createdByUid: 'u1',
        lines: [
          PurchaseOrderLine(
            id: 'l1',
            itemType: 'product',
            itemId: 'p1',
            itemNameSnapshot: 'Test Product',
            orderedQuantity: 10,
          )
        ],
      );

      await repo.createPurchaseOrder(order);
      final query = await firestore.collection('merchants').doc('m1').collection('purchase_orders').get();
      final fetched = PurchaseOrder.fromJson(query.docs.first.data()..['id'] = query.docs.first.id);
      expect(fetched!.status, 'draft');
      expect(fetched.lines.first.orderedQuantity, 10);
    });

    test('partial receipt receives subset without duplicating', () async {
      final order = PurchaseOrder(
        id: 'o1',
        merchantId: 'm1',
        branchId: 'b1',
        supplierId: 's1',
        status: 'draft',
        createdAt: DateTime.now(),
        createdByUid: 'u1',
        lines: [
          PurchaseOrderLine(
            id: 'l1',
            itemType: 'product',
            itemId: 'p1',
            itemNameSnapshot: 'Test Product',
            orderedQuantity: 10,
            unitCost: 50,
          )
        ],
      );

      await firestore.collection('merchants').doc('m1').collection('suppliers').doc('s1').set({
        'name': 'Test Supplier',
        'totalDebt': 0,
      });

      await firestore.collection('merchants').doc('m1').collection('purchase_orders').doc('o1').set(order.toJson());

      // Receive 5 items
      await repo.receiveGoods(
        order: order,
        receiptLines: [
          PurchaseOrderLine(
            id: 'l1',
            itemType: 'product',
            itemId: 'p1',
            itemNameSnapshot: 'Test Product',
            orderedQuantity: 10,
            receivedQuantity: 5,
            unitCost: 50,
          )
        ],
        actorUid: 'u2',
        actorName: 'User 2',
        operationId: 'op1',
      );

      final query = await firestore.collection('merchants').doc('m1').collection('purchase_orders').get();
      final fetched = PurchaseOrder.fromJson(query.docs.first.data()..['id'] = query.docs.first.id);
      expect(fetched!.status, 'partiallyReceived');
      expect(fetched.lines.first.receivedQuantity, 5);

      // Check if invoice was created
      final invoices = await firestore.collection('merchants').doc('m1').collection('purchase_invoices').get();
      expect(invoices.docs.length, 1);
    });

    test('idempotency: fully received PO cannot be received again', () async {
      final order = PurchaseOrder(
        id: 'o1',
        merchantId: 'm1',
        branchId: 'b1',
        supplierId: 's1',
        status: 'received', // Already received
        createdAt: DateTime.now(),
        createdByUid: 'u1',
        lines: [
          PurchaseOrderLine(
            id: 'l1',
            itemType: 'product',
            itemId: 'p1',
            itemNameSnapshot: 'Test Product',
            orderedQuantity: 10,
            receivedQuantity: 10,
            unitCost: 50,
          )
        ],
      );

      await firestore.collection('merchants').doc('m1').collection('purchase_orders').doc('o1').set(order.toJson());

      expect(
        () => repo.receiveGoods(order: order, receiptLines: order.lines, actorUid: 'u2', actorName: 'User 2', operationId: 'op2'),
        throwsA(isA<Exception>())
      );
    });
  });
}
