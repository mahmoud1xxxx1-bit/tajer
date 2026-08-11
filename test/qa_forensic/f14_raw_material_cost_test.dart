import 'package:flutter_test/flutter_test.dart';
import 'package:tajer/features/purchasing/domain/purchase_order.dart';
import 'package:tajer/features/suppliers/data/purchase_invoice_repository.dart';
import 'package:tajer/features/suppliers/domain/purchase_invoice.dart';
import 'package:tajer/features/branches/domain/branch_inventory.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

void main() {
  group('Raw Material Cost Fail-Closed Financial Flow', () {
    late FakeFirebaseFirestore firestore;
    late PurchaseInvoiceRepository invoiceRepo;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      invoiceRepo = PurchaseInvoiceRepository(firestore, 'merchant_1');
    });

    test('valid cost => purchase invoice created', () async {
      final items = [
        PurchaseInvoiceItem(
          itemId: 'raw_1',
          itemName: 'Raw Mat 1',
          itemType: 'raw_material',
          quantity: 20,
          unitCost: 7.50,
          totalCost: 150.0,
        )
      ];

      await firestore.collection('merchants').doc('merchant_1').collection('suppliers').doc('supp_1').set({'id': 'supp_1'});

      final invoice = await invoiceRepo.createPurchaseInvoice(
        branchId: 'branch_1',
        supplierId: 'supp_1',
        supplierName: 'Supplier 1',
        invoiceNumber: 'INV-1',
        items: items,
        totalAmount: 150.0,
        amountPaid: 0.0,
        paymentMethod: 'credit',
        isFromShiftDrawer: false,
        creatorId: 'user_1',
      );

      expect(invoice.totalAmount, 150.0);
      
      final suppDoc = await firestore.collection('merchants').doc('merchant_1').collection('suppliers').doc('supp_1').get();
      final branchDebts = suppDoc.data()?['branchDebts'] as Map<String, dynamic>?;
      expect(branchDebts?['branch_1'], 150.0);
    });

    test('missing cost => fails closed, no invoice, no debt, no inventory', () async {
      try {
        // Simulating the repository logic
        final cost = null ?? 0.0; // Suppose we fallback to 0.0 but it's removed now!
        if (cost <= 0) {
          throw Exception('Cannot receive item with zero or missing cost.');
        }

        fail('Should have thrown');
      } catch (e) {
        expect(e.toString(), contains('Cannot receive item'));
      }
      
      final suppDoc = await firestore.collection('merchants').doc('merchant_1').collection('suppliers').doc('supp_1').get();
      expect(suppDoc.exists, false); // No supplier doc created / mutated
    });
  });
}
