import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tajer/features/branches/data/branch_inventory_repository.dart';
import 'package:tajer/features/customers/domain/customer.dart';
import 'package:tajer/features/customers/domain/customer_debt_payment.dart';
import 'package:tajer/features/expenses/domain/expense.dart';
import 'package:tajer/features/orders/data/branch_aware_order_repository.dart';
import 'package:tajer/features/orders/domain/cart_item.dart';
import 'package:tajer/features/orders/domain/order.dart';
import 'package:tajer/features/reports/data/reports_service.dart';

const merchantId = 'qa_merchant';
const mainBranch = 'main';
const branchB = 'branch_b';
const readyA = 'ready_a';
const madeA = 'made_a';
const raw1 = 'raw_1';
const raw2 = 'raw_2';
const raw3 = 'raw_3';
const customerMain = 'customer_main';
const customerB = 'customer_b';
const shiftMain = 'shift_main';
const shiftB = 'shift_b';

final fixedDate = DateTime(2026, 8, 9, 10);

class QaResult {
  final String id;
  final String category;
  final String name;
  final int? seed;
  final Object? input;
  final Object? expected;
  final Object? actual;
  final Object? delta;
  final String status;
  final String failureReason;
  final int durationMs;

  QaResult({
    required this.id,
    required this.category,
    required this.name,
    this.seed,
    this.input,
    this.expected,
    this.actual,
    this.delta,
    required this.status,
    this.failureReason = '',
    this.durationMs = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category,
        'name': name,
        'seed': seed,
        'input': input,
        'expected': expected,
        'actual': actual,
        'delta': delta,
        'status': status,
        'failure_reason': failureReason,
        'duration_ms': durationMs,
      };
}

class QaEvidence {
  final rows = <QaResult>[];

  Future<void> checkNum(
    String id,
    String category,
    String name, {
    required num expected,
    required num actual,
    Object? input,
    int? seed,
    double tolerance = 0.000001,
  }) async {
    final delta = (actual - expected).toDouble();
    rows.add(QaResult(
      id: id,
      category: category,
      name: name,
      seed: seed,
      input: input,
      expected: expected,
      actual: actual,
      delta: delta,
      status: delta.abs() <= tolerance ? 'PASS' : 'FAIL',
      failureReason:
          delta.abs() <= tolerance ? '' : 'numeric delta exceeds tolerance',
    ));
  }

  void checkBool(
    String id,
    String category,
    String name, {
    required bool expected,
    required bool actual,
    Object? input,
    int? seed,
  }) {
    rows.add(QaResult(
      id: id,
      category: category,
      name: name,
      seed: seed,
      input: input,
      expected: expected,
      actual: actual,
      delta: expected == actual ? 0 : 1,
      status: expected == actual ? 'PASS' : 'FAIL',
      failureReason: expected == actual ? '' : 'boolean assertion mismatch',
    ));
  }

  void notExecuted(
    String id,
    String category,
    String name,
    String reason,
  ) {
    rows.add(QaResult(
      id: id,
      category: category,
      name: name,
      expected: 'executed assertion',
      actual: 'not executed',
      status: 'NOT_EXECUTED',
      failureReason: reason,
    ));
  }

  void blocked(
    String id,
    String category,
    String name,
    String reason,
  ) {
    rows.add(QaResult(
      id: id,
      category: category,
      name: name,
      expected: 'executed assertion',
      actual: 'blocked',
      status: 'BLOCKED',
      failureReason: reason,
    ));
  }

  Future<void> write() async {
    final dir = Directory('qa_evidence');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final encoded = const JsonEncoder.withIndent('  ')
        .convert(rows.map((row) => row.toJson()).toList());
    File('qa_evidence/qa_results.json').writeAsStringSync(encoded);
    File('qa_evidence/qa_results.csv').writeAsStringSync(_csv());
    File('qa_evidence/qa_defects.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(_defects()),
    );
  }

  String _csv() {
    final fields = [
      'id',
      'category',
      'name',
      'seed',
      'input',
      'expected',
      'actual',
      'delta',
      'status',
      'failure_reason',
      'duration_ms',
    ];
    String esc(Object? value) =>
        '"${(value ?? '').toString().replaceAll('"', '""')}"';
    return [
      fields.join(','),
      ...rows.map((row) => [
            row.id,
            row.category,
            row.name,
            row.seed,
            jsonEncode(row.input),
            jsonEncode(row.expected),
            jsonEncode(row.actual),
            row.delta,
            row.status,
            row.failureReason,
            row.durationMs,
          ].map(esc).join(',')),
    ].join('\n');
  }

  List<Map<String, dynamic>> _defects() {
    return rows
        .where((row) => row.status == 'FAIL' || row.status == 'BLOCKED')
        .map((row) => {
              'id': 'DEF-${row.id}',
              'severity': _severity(row.category),
              'test_id': row.id,
              'area': row.category,
              'steps': row.name,
              'expected': row.expected,
              'actual': row.actual,
              'accounting_impact':
                  row.category == 'accounting' ? 'possible' : 'none observed',
              'branch_isolation_impact':
                  row.category == 'branch' ? 'possible' : 'none observed',
              'security_impact':
                  row.category == 'security' ? 'possible' : 'none observed',
              'data_integrity_impact':
                  row.category == 'atomicity' || row.category == 'inventory'
                      ? 'possible'
                      : 'none observed',
              'reproduction_seed': row.seed,
              'likely_code_area': 'See test category ${row.category}',
              'failure_reason': row.failureReason,
            })
        .toList();
  }

  String _severity(String category) {
    if (category == 'accounting' ||
        category == 'branch' ||
        category == 'security' ||
        category == 'atomicity' ||
        category == 'customer_debt' ||
        category == 'randomized') {
      return 'P0';
    }
    if (category == 'shift' || category == 'legacy') return 'P1';
    return 'P2';
  }
}

class ExpectedLedger {
  double revenue = 0;
  double cogs = 0;
  double tax = 0;
  double expenses = 0;
  double cash = 0;
  double card = 0;
  double transfer = 0;
  double ar = 0;
  double get grossProfit => revenue - tax - cogs;
  double get netProfit => revenue - tax - cogs - expenses;
}

Future<double> qty(
    FakeFirebaseFirestore db, String branch, String type, String itemId) async {
  final snap = await db
      .collection('merchants')
      .doc(merchantId)
      .collection('branch_inventory')
      .doc('${branch}_${type}_$itemId')
      .get();
  return (snap.data()?['quantity'] as num?)?.toDouble() ?? 0.0;
}

Future<Map<String, dynamic>?> shift(FakeFirebaseFirestore db, String id) async {
  return (await db.collection('shifts').doc(id).get()).data();
}

Future<void> selectBranch(String branch) async {
  SharedPreferences.setMockInitialValues(
      {'selected_branch_$merchantId': branch});
}

Future<void> seedBase(FakeFirebaseFirestore db) async {
  await db.collection('users').doc('test-user').set({'role': 'merchant'});
  Timestamp ts() => Timestamp.fromDate(fixedDate);
  Future<void> inv(String branch, String type, String item, double quantity) {
    return db
        .collection('merchants')
        .doc(merchantId)
        .collection('branch_inventory')
        .doc('${branch}_${type}_$item')
        .set({
      'id': '${branch}_${type}_$item',
      'merchantId': merchantId,
      'branchId': branch,
      'itemId': item,
      'itemType': type,
      'quantity': quantity,
      'initialQuantity': quantity,
      'updatedAt': ts(),
    });
  }

  await db.collection('products').doc(readyA).set({
    'id': readyA,
    'merchantId': merchantId,
    'name': 'READY_A',
    'price': 20.0,
    'quantity': 0,
    'recipe': [],
    'isManufacturedOnDemand': false,
    'isArchived': false,
    'taxMode': 'store',
    'createdAt': ts(),
    'updatedAt': ts(),
  });
  await db.collection('products').doc(madeA).set({
    'id': madeA,
    'merchantId': merchantId,
    'name': 'MADE_A',
    'price': 50.0,
    'quantity': 0,
    'recipe': [
      {'rawMaterialId': raw1, 'amountRequired': 2.0},
      {'rawMaterialId': raw2, 'amountRequired': 1.0},
    ],
    'isManufacturedOnDemand': true,
    'isArchived': false,
    'taxMode': 'store',
    'createdAt': ts(),
    'updatedAt': ts(),
  });
  for (final entry in {readyA: 5.0, raw1: 3.0, raw2: 4.0, raw3: 1.0}.entries) {
    await db
        .collection('merchants')
        .doc(merchantId)
        .collection('product_costs')
        .doc(entry.key)
        .set({
      'merchantId': merchantId,
      'productId': entry.key,
      'costPrice': entry.value,
      'updatedAt': ts(),
    });
  }
  await inv(mainBranch, 'product', readyA, 100);
  await inv(branchB, 'product', readyA, 40);
  await inv(mainBranch, 'product', madeA, 0);
  await inv(branchB, 'product', madeA, 0);
  await inv(mainBranch, 'raw_material', raw1, 100);
  await inv(mainBranch, 'raw_material', raw2, 100);
  await inv(branchB, 'raw_material', raw1, 0);
  await inv(branchB, 'raw_material', raw2, 0);
  await db.collection('shifts').doc(shiftMain).set({
    'id': shiftMain,
    'merchantId': merchantId,
    'branchId': mainBranch,
    'status': 'open',
    'startTime': ts(),
    'startCash': 0.0,
  });
  await db.collection('shifts').doc(shiftB).set({
    'id': shiftB,
    'merchantId': merchantId,
    'branchId': branchB,
    'status': 'open',
    'startTime': ts(),
    'startCash': 0.0,
  });
  await db.collection('customers').doc(customerMain).set({
    'id': customerMain,
    'merchantId': merchantId,
    'branchId': mainBranch,
    'name': 'CUSTOMER_MAIN',
    'phone': '0500000000',
    'totalPurchases': 0.0,
    'orderCount': 0,
    'totalDebt': 0.0,
    'createdAt': ts(),
  });
  await db.collection('customers').doc(customerB).set({
    'id': customerB,
    'merchantId': merchantId,
    'branchId': branchB,
    'name': 'CUSTOMER_B',
    'phone': '0500000000',
    'totalPurchases': 0.0,
    'orderCount': 0,
    'totalDebt': 0.0,
    'createdAt': ts(),
  });
}

AppOrder order({
  required String id,
  required String productId,
  required String productName,
  required int quantity,
  required double unitPrice,
  required String paymentMethod,
  required double paidAmount,
  bool made = false,
  bool isCredit = false,
  String customerId = 'walk_in',
  double? splitCash,
  double? splitCard,
  double? taxPct,
  bool? inclusive,
}) {
  final total = unitPrice * quantity;
  return AppOrder(
    id: id,
    merchantId: merchantId,
    customerId: customerId,
    customerName: customerId,
    items: [
      CartItem(
        productId: productId,
        productName: productName,
        quantity: quantity,
        price: unitPrice,
        total: total,
        isManufacturedOnDemand: made,
        taxPercentage: taxPct,
        isTaxInclusive: inclusive,
      ),
    ],
    total: total,
    paidAmount: paidAmount,
    isCredit: isCredit,
    paymentMethod: paymentMethod,
    splitCashAmount: splitCash,
    splitNetworkAmount: splitCard,
    createdAt: fixedDate,
  );
}

ReportsService reports(List<AppOrder> orders,
    {List<Expense> expenses = const [],
    List<CustomerDebtPayment> debtPayments = const [],
    double tax = 0}) {
  return ReportsService(
    orders,
    const [],
    expenses,
    const [],
    const [],
    debtPayments: debtPayments,
    canViewCost: true,
    defaultTaxPercentage: tax,
  );
}

void main() {
  final evidence = QaEvidence();

  tearDownAll(() async {
    await evidence.write();
  });

  test('forensic deterministic repository/accounting/inventory matrix',
      () async {
    final db = FakeFirebaseFirestore();
    await seedBase(db);
    final repo = BranchAwareOrderRepository(db, testUid: 'test-user');

    await selectBranch(mainBranch);
    final readyMain = await repo.createOrder(
      order(
        id: 'qa_ready_main',
        productId: readyA,
        productName: 'READY_A',
        quantity: 2,
        unitPrice: 20,
        paymentMethod: 'cash',
        paidAmount: 40,
      ),
      shiftId: shiftMain,
    );
    final readyReport = reports([readyMain]);
    await evidence.checkNum(
        'QA-009-REV', 'accounting', 'READY_A main sale revenue',
        expected: 40, actual: readyReport.totalRevenue);
    await evidence.checkNum(
        'QA-009-COGS', 'accounting', 'READY_A main sale COGS',
        expected: 10, actual: readyReport.totalCOGS);
    await evidence.checkNum(
        'QA-009-GP', 'accounting', 'READY_A main gross profit',
        expected: 30, actual: readyReport.netProfit);
    await evidence.checkNum(
        'QA-009-MAIN-STOCK', 'inventory', 'READY_A main stock decrement',
        expected: 98, actual: await qty(db, mainBranch, 'product', readyA));
    await evidence.checkNum('QA-009-BRANCHB-STOCK', 'branch',
        'READY_A branch B unchanged by main sale',
        expected: 40, actual: await qty(db, branchB, 'product', readyA));

    await db
        .collection('merchants')
        .doc(merchantId)
        .collection('product_costs')
        .doc(readyA)
        .update({'costPrice': 8.0});
    final readyNew = await repo.createOrder(
      order(
        id: 'qa_ready_new_cost',
        productId: readyA,
        productName: 'READY_A',
        quantity: 1,
        unitPrice: 20,
        paymentMethod: 'cash',
        paidAmount: 20,
      ),
      shiftId: shiftMain,
    );
    await evidence.checkNum(
        'QA-010-OLD-COST', 'accounting', 'historical COGS remains old cost',
        expected: 5, actual: readyMain.items.single.costPrice ?? -1);
    await evidence.checkNum(
        'QA-010-NEW-COST', 'accounting', 'new sale uses edited current cost',
        expected: 8, actual: readyNew.items.single.costPrice ?? -1);

    final madeMain = await repo.createOrder(
      order(
        id: 'qa_made_main',
        productId: madeA,
        productName: 'MADE_A',
        quantity: 3,
        unitPrice: 50,
        paymentMethod: 'cash',
        paidAmount: 150,
        made: true,
      ),
      shiftId: shiftMain,
    );
    final madeReport = reports([madeMain]);
    await evidence.checkNum('QA-011-REV', 'made_to_order', 'MADE_A revenue',
        expected: 150, actual: madeReport.totalRevenue);
    await evidence.checkNum(
        'QA-011-COGS', 'made_to_order', 'MADE_A recipe COGS',
        expected: 30, actual: madeReport.totalCOGS);
    await evidence.checkNum(
        'QA-011-RAW1', 'inventory', 'MADE_A raw1 main consumption',
        expected: 94, actual: await qty(db, mainBranch, 'raw_material', raw1));
    await evidence.checkNum(
        'QA-011-RAW2', 'inventory', 'MADE_A raw2 main consumption',
        expected: 97, actual: await qty(db, mainBranch, 'raw_material', raw2));
    await evidence.checkNum('QA-012-FINISHED', 'made_to_order',
        'MADE_A finished stock remains irrelevant',
        expected: 0, actual: await qty(db, mainBranch, 'product', madeA));

    await selectBranch(branchB);
    var denied = false;
    try {
      await repo.createOrder(
        order(
          id: 'qa_made_branch_short',
          productId: madeA,
          productName: 'MADE_A',
          quantity: 1,
          unitPrice: 50,
          paymentMethod: 'cash',
          paidAmount: 50,
          made: true,
        ),
        shiftId: shiftB,
      );
    } catch (_) {
      denied = true;
    }
    evidence.checkBool(
        'QA-013-DENY', 'atomicity', 'made-to-order raw shortage denied',
        expected: true, actual: denied);
    evidence.checkBool(
        'QA-013-NO-ORDER', 'atomicity', 'raw shortage creates no order',
        expected: false,
        actual:
            (await db.collection('orders').doc('qa_made_branch_short').get())
                .exists);
    await evidence.checkNum('QA-014-MAIN-RAW-UNCHANGED', 'branch',
        'branch B raw shortage does not consume main raw1',
        expected: 94, actual: await qty(db, mainBranch, 'raw_material', raw1));

    await selectBranch(mainBranch);
    await repo.updateOrderStatus(madeMain, 'cancelled');
    await evidence.checkNum('QA-015-RAW1-RESTORE', 'inventory',
        'made-to-order cancellation restores raw1 to origin branch',
        expected: 100, actual: await qty(db, mainBranch, 'raw_material', raw1));
    await evidence.checkNum('QA-015-RAW2-RESTORE', 'inventory',
        'made-to-order cancellation restores raw2 to origin branch',
        expected: 100, actual: await qty(db, mainBranch, 'raw_material', raw2));
    await repo.updateOrderStatus(
        madeMain.copyWith(status: 'cancelled'), 'cancelled');
    await evidence.checkNum('QA-015-IDEMPOTENT', 'atomicity',
        'second cancellation does not restore raw twice',
        expected: 100, actual: await qty(db, mainBranch, 'raw_material', raw1));

    final readyCancel = await repo.createOrder(
      order(
        id: 'qa_ready_cancel',
        productId: readyA,
        productName: 'READY_A',
        quantity: 3,
        unitPrice: 20,
        paymentMethod: 'cash',
        paidAmount: 60,
      ),
      shiftId: shiftMain,
    );
    final afterReadySale = await qty(db, mainBranch, 'product', readyA);
    await repo.updateOrderStatus(readyCancel, 'cancelled');
    await repo.updateOrderStatus(
        readyCancel.copyWith(status: 'cancelled'), 'cancelled');
    await evidence.checkNum('QA-016-AFTER-SALE', 'inventory',
        'ready cancellation sale decremented once before cancellation',
        expected: 94, actual: afterReadySale);
    await evidence.checkNum('QA-016-RESTORE', 'inventory',
        'ready cancellation restores exactly once',
        expected: 97, actual: await qty(db, mainBranch, 'product', readyA));

    for (var i = 0; i < 5; i++) {
      await repo.createOrder(
        order(
          id: 'qa_idempotent',
          productId: readyA,
          productName: 'READY_A',
          quantity: 1,
          unitPrice: 20,
          paymentMethod: 'cash',
          paidAmount: 20,
        ),
        shiftId: shiftMain,
      );
    }
    final idempotentOrders = await db
        .collection('orders')
        .where('id', isEqualTo: 'qa_idempotent')
        .get();
    evidence.checkBool('QA-017-ONE-ORDER', 'atomicity',
        'same order id repeated creates one order',
        expected: true, actual: idempotentOrders.docs.length == 1);

    final invRepo = BranchInventoryRepository(db, merchantId);
    await invRepo.setQuantity(
        branchId: mainBranch,
        itemType: 'product',
        itemId: readyA,
        quantity: 100,
        initialQuantity: 100);
    await invRepo.setQuantity(
        branchId: branchB,
        itemType: 'product',
        itemId: readyA,
        quantity: 20,
        initialQuantity: 20);
    final transferId = await invRepo.transferQuantity(
      fromBranchId: mainBranch,
      toBranchId: branchB,
      itemType: 'product',
      itemId: readyA,
      itemName: 'READY_A',
      quantity: 15,
    );
    await evidence.checkNum(
        'QA-021-MAIN', 'inventory', 'transfer decrements source',
        expected: 85, actual: await qty(db, mainBranch, 'product', readyA));
    await evidence.checkNum(
        'QA-021-BRANCH', 'inventory', 'transfer increments destination',
        expected: 35, actual: await qty(db, branchB, 'product', readyA));
    evidence.checkBool('QA-021-LOG', 'inventory', 'transfer id exists',
        expected: true, actual: transferId.isNotEmpty);
    var transferDenied = false;
    try {
      await invRepo.transferQuantity(
        fromBranchId: mainBranch,
        toBranchId: branchB,
        itemType: 'product',
        itemId: readyA,
        itemName: 'READY_A',
        quantity: 500,
      );
    } catch (_) {
      transferDenied = true;
    }
    evidence.checkBool('QA-022-DENY', 'atomicity', 'invalid transfer denied',
        expected: true, actual: transferDenied);
    await evidence.checkNum('QA-022-MAIN-UNCHANGED', 'inventory',
        'invalid transfer leaves source unchanged',
        expected: 85, actual: await qty(db, mainBranch, 'product', readyA));
    await invRepo.setQuantityWithAudit(
      branchId: mainBranch,
      itemType: 'product',
      itemId: readyA,
      itemName: 'READY_A',
      quantity: 18,
      legacyMainQuantity: 0,
      reason: 'qa stocktake 20 to 18',
    );
    await evidence.checkNum('QA-025-STOCKTAKE-DEC', 'inventory',
        'stocktake-style correction 20 to 18',
        expected: 18, actual: await qty(db, mainBranch, 'product', readyA));
    await invRepo.setQuantityWithAudit(
      branchId: mainBranch,
      itemType: 'product',
      itemId: readyA,
      itemName: 'READY_A',
      quantity: 21,
      legacyMainQuantity: 0,
      reason: 'qa stocktake 18 to 21',
    );
    await evidence.checkNum('QA-025-STOCKTAKE-INC', 'inventory',
        'stocktake-style correction 18 to 21',
        expected: 21, actual: await qty(db, mainBranch, 'product', readyA));
    await evidence.checkNum('QA-026-STOCKTAKE-ISO', 'branch',
        'main stocktake does not alter branch B',
        expected: 35, actual: await qty(db, branchB, 'product', readyA));
  });

  test('remaining forensic atomicity and adversarial items', () async {
    final npx = Platform.isWindows ? 'npx.cmd' : 'npx';
    final env = Map<String, String>.from(Platform.environment);
    if (Platform.isWindows && Directory(r'C:\dev-tools\jdk-21').existsSync()) {
      env['JAVA_HOME'] = r'C:\dev-tools\jdk-21';
      env['PATH'] = "${env['JAVA_HOME']}\\bin;${env['PATH']}";
    }
    final result = await Process.run(
      npx,
      [
        'firebase-tools',
        'emulators:exec',
        '--only',
        'firestore',
        'node functions/forensic_remaining_emulator_test.js',
      ],
      environment: env,
    );
    final outputFile = File('qa_evidence/remaining_emulator_results.json');
    if (result.exitCode != 0 || !outputFile.existsSync()) {
      for (final id in [
        'QA-018-EMULATOR-CONCURRENCY',
        'QA-019-EMULATOR-RAW-CONCURRENCY',
        'QA-037-RULE-BYPASS-CUSTOMER-DEBT',
        'QA-076-ATOMIC-INJECTED-WRITE-FAILURE',
        'QA-077-ATOMIC-CANCEL-FAILURE',
      ]) {
        evidence.checkBool(
          id,
          id == 'QA-037-RULE-BYPASS-CUSTOMER-DEBT' ? 'security' : 'atomicity',
          'Firestore Emulator remaining QA item',
          input: {
            'exit_code': result.exitCode,
            'stdout': result.stdout.toString(),
            'stderr': result.stderr.toString(),
          },
          expected: true,
          actual: false,
        );
      }
      return;
    }

    final rows = (jsonDecode(outputFile.readAsStringSync()) as List<dynamic>)
        .cast<Map<String, dynamic>>();
    for (final row in rows) {
      evidence.checkBool(
        row['id'].toString(),
        row['category'].toString(),
        row['name'].toString(),
        input: row['input'],
        expected: row['expected'] == true,
        actual: row['actual'] == true,
      );
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
  test('forensic accounting reference model vs ReportsService', () async {
    final orders = [
      order(
              id: 'cash100',
              productId: readyA,
              productName: 'READY_A',
              quantity: 5,
              unitPrice: 20,
              paymentMethod: 'cash',
              paidAmount: 100)
          .copyWith(items: [
        const CartItem(
            productId: readyA,
            productName: 'READY_A',
            quantity: 5,
            price: 20,
            total: 100,
            costPrice: 5)
      ]),
      order(
              id: 'card100',
              productId: readyA,
              productName: 'READY_A',
              quantity: 5,
              unitPrice: 20,
              paymentMethod: 'card',
              paidAmount: 100)
          .copyWith(items: [
        const CartItem(
            productId: readyA,
            productName: 'READY_A',
            quantity: 5,
            price: 20,
            total: 100,
            costPrice: 5)
      ]),
      order(
              id: 'transfer100',
              productId: readyA,
              productName: 'READY_A',
              quantity: 5,
              unitPrice: 20,
              paymentMethod: 'transfer',
              paidAmount: 100)
          .copyWith(items: [
        const CartItem(
            productId: readyA,
            productName: 'READY_A',
            quantity: 5,
            price: 20,
            total: 100,
            costPrice: 5)
      ]),
      order(
              id: 'split100',
              productId: readyA,
              productName: 'READY_A',
              quantity: 5,
              unitPrice: 20,
              paymentMethod: 'split',
              paidAmount: 100,
              splitCash: 40,
              splitCard: 60)
          .copyWith(items: [
        const CartItem(
            productId: readyA,
            productName: 'READY_A',
            quantity: 5,
            price: 20,
            total: 100,
            costPrice: 5)
      ]),
      order(
              id: 'credit40',
              productId: readyA,
              productName: 'READY_A',
              quantity: 2,
              unitPrice: 20,
              paymentMethod: 'cash',
              paidAmount: 10,
              isCredit: true)
          .copyWith(items: [
        const CartItem(
            productId: readyA,
            productName: 'READY_A',
            quantity: 2,
            price: 20,
            total: 40,
            costPrice: 5)
      ]),
    ];
    final debtPayments = [
      CustomerDebtPayment(
        id: 'debt-cash-30',
        merchantId: merchantId,
        customerId: customerMain,
        branchId: mainBranch,
        shiftId: shiftMain,
        amount: 30,
        paymentMethod: 'cash',
        createdAt: fixedDate,
      ),
    ];
    final expenses = [
      Expense(
        id: 'expense-main',
        merchantId: merchantId,
        branchId: mainBranch,
        title: 'Rent',
        amount: 30,
        date: fixedDate,
        createdAt: fixedDate,
      ),
    ];
    final expected = ExpectedLedger()
      ..revenue = 440
      ..cogs = 110
      ..expenses = 30
      ..cash = 180
      ..card = 160
      ..transfer = 100
      ..ar = 0;
    final actual =
        reports(orders, expenses: expenses, debtPayments: debtPayments);
    await evidence.checkNum('QA-027-033-REV', 'accounting',
        'cash/card/transfer/split/credit revenue',
        expected: expected.revenue, actual: actual.totalRevenue);
    await evidence.checkNum(
        'QA-027-033-COGS', 'accounting', 'cash/card/transfer/split/credit COGS',
        expected: expected.cogs, actual: actual.totalCOGS);
    await evidence.checkNum(
        'QA-027-033-EXP', 'accounting', 'expense affects net profit only',
        expected: expected.expenses, actual: actual.totalExpenses);
    await evidence.checkNum(
        'QA-027-033-NET', 'accounting', 'net profit independent reference',
        expected: expected.netProfit, actual: actual.netProfit);
    await evidence.checkNum(
        'QA-027-033-DEBT', 'customer_debt', 'credit sale creates AR',
        expected: expected.ar, actual: actual.totalDebt);
    final payments = actual.paymentMethodsBreakdown;
    await evidence.checkNum('QA-030-CASHFLOW-CASH', 'shift',
        'cash flow includes cash sale, split cash and debt collection',
        expected: expected.cash, actual: payments['cash'] ?? -1);
    await evidence.checkNum('QA-030-CASHFLOW-CARD', 'shift',
        'card flow includes card and split card',
        expected: expected.card, actual: payments['card'] ?? -1);
    await evidence.checkNum('QA-030-CASHFLOW-TRANSFER', 'shift',
        'transfer flow is isolated from cash',
        expected: expected.transfer, actual: payments['transfer'] ?? -1);

    final vatOrder = order(
      id: 'vat115',
      productId: readyA,
      productName: 'READY_A',
      quantity: 1,
      unitPrice: 115,
      paymentMethod: 'cash',
      paidAmount: 115,
      taxPct: 15,
      inclusive: true,
    );
    final vatReport = reports([vatOrder], tax: 0);
    await evidence.checkNum(
        'QA-041-VAT', 'accounting', 'VAT inclusive extraction 115 at 15%',
        expected: 15, actual: vatReport.totalTaxCollected);
  });

  test('forensic serialization and legacy compatibility', () {
    final orderJson = order(
      id: 'legacy107',
      productId: readyA,
      productName: 'READY_A',
      quantity: 1,
      unitPrice: 20,
      paymentMethod: 'cash',
      paidAmount: 20,
    ).copyWith(items: [
      const CartItem(
          productId: readyA,
          productName: 'READY_A',
          quantity: 1,
          price: 20,
          total: 20,
          costPrice: 5)
    ]).toInternalJson();
    final decoded = AppOrder.fromJson(orderJson);
    evidence.checkBool('QA-079-ORDER-ROUNDTRIP', 'legacy',
        'order round trip preserves branch and cost snapshot',
        expected: true,
        actual: decoded.branchId == mainBranch &&
            decoded.items.single.costPrice == 5);
    final legacyBranchless = Map<String, dynamic>.from(orderJson)
      ..remove('branchId');
    final legacyOrder = AppOrder.fromJson(legacyBranchless);
    evidence.checkBool('QA-080-ORDER-107', 'legacy',
        'legacy 107 order without branchId maps to main',
        expected: true, actual: legacyOrder.branchId == mainBranch);
    final customer = Customer.fromJson({
      'id': 'legacy_customer',
      'merchantId': merchantId,
      'name': 'Legacy',
      'phone': '1',
      'createdAt': Timestamp.fromDate(fixedDate),
    });
    evidence.checkBool('QA-081-CUSTOMER-LEGACY', 'legacy',
        'legacy customer without branchId maps to main',
        expected: true, actual: customer.branchId == mainBranch);
    final zeroCostReport = reports([
      order(
              id: 'zero',
              productId: readyA,
              productName: 'READY_A',
              quantity: 1,
              unitPrice: 20,
              paymentMethod: 'cash',
              paidAmount: 20)
          .copyWith(items: [
        const CartItem(
            productId: readyA,
            productName: 'READY_A',
            quantity: 1,
            price: 20,
            total: 20,
            costPrice: 0)
      ])
    ]);
    evidence.checkBool('QA-089-ZERO-COST', 'accounting',
        'zero cost is complete and not treated as missing',
        expected: true,
        actual: zeroCostReport.isCOGSComplete && zeroCostReport.totalCOGS == 0);
    final missingCostReport = reports([
      order(
          id: 'missing',
          productId: readyA,
          productName: 'READY_A',
          quantity: 1,
          unitPrice: 20,
          paymentMethod: 'cash',
          paidAmount: 20)
    ]);
    evidence.checkBool('QA-090-MISSING-COST', 'accounting',
        'missing cost marks COGS incomplete',
        expected: true, actual: !missingCostReport.isCOGSComplete);
  });

  test('seeded randomized independent ledger vs ReportsService', () async {
    var operations = 0;
    final failingSeeds = <int>[];
    for (var seed = 1; seed <= 100; seed++) {
      final random = Random(seed);
      final orders = <AppOrder>[];
      final expenses = <Expense>[];
      final debtPayments = <CustomerDebtPayment>[];
      final expected = ExpectedLedger();
      for (var i = 0; i < 50; i++) {
        operations++;
        final kind = random.nextInt(6);
        if (kind == 0) {
          final q = 1 + random.nextInt(4);
          final total = q * 20.0;
          final payment = ['cash', 'card', 'transfer'][random.nextInt(3)];
          expected.revenue += total;
          expected.cogs += q * 5;
          if (payment == 'cash') expected.cash += total;
          if (payment == 'card') expected.card += total;
          if (payment == 'transfer') expected.transfer += total;
          orders.add(order(
                  id: 's${seed}_$i',
                  productId: readyA,
                  productName: 'READY_A',
                  quantity: q,
                  unitPrice: 20,
                  paymentMethod: payment,
                  paidAmount: total)
              .copyWith(items: [
            CartItem(
                productId: readyA,
                productName: 'READY_A',
                quantity: q,
                price: 20,
                total: total,
                costPrice: 5)
          ]));
        } else if (kind == 1) {
          expected.revenue += 100;
          expected.cogs += 25;
          expected.cash += 40;
          expected.card += 60;
          orders.add(order(
                  id: 'sp${seed}_$i',
                  productId: readyA,
                  productName: 'READY_A',
                  quantity: 5,
                  unitPrice: 20,
                  paymentMethod: 'split',
                  paidAmount: 100,
                  splitCash: 40,
                  splitCard: 60)
              .copyWith(items: [
            const CartItem(
                productId: readyA,
                productName: 'READY_A',
                quantity: 5,
                price: 20,
                total: 100,
                costPrice: 5)
          ]));
        } else if (kind == 2) {
          expected.revenue += 40;
          expected.cogs += 10;
          expected.cash += 10;
          expected.ar += 30;
          orders.add(order(
                  id: 'cr${seed}_$i',
                  productId: readyA,
                  productName: 'READY_A',
                  quantity: 2,
                  unitPrice: 20,
                  paymentMethod: 'cash',
                  paidAmount: 10,
                  isCredit: true)
              .copyWith(items: [
            const CartItem(
                productId: readyA,
                productName: 'READY_A',
                quantity: 2,
                price: 20,
                total: 40,
                costPrice: 5)
          ]));
        } else if (kind == 3 && expected.ar >= 10) {
          expected.ar -= 10;
          expected.cash += 10;
          debtPayments.add(CustomerDebtPayment(
              id: 'dp${seed}_$i',
              merchantId: merchantId,
              customerId: customerMain,
              amount: 10,
              paymentMethod: 'cash',
              createdAt: fixedDate));
        } else if (kind == 4) {
          expected.expenses += 7;
          expenses.add(Expense(
              id: 'e${seed}_$i',
              merchantId: merchantId,
              branchId: mainBranch,
              title: 'Expense',
              amount: 7,
              date: fixedDate,
              createdAt: fixedDate));
        } else {
          orders.add(order(
                  id: 'can${seed}_$i',
                  productId: readyA,
                  productName: 'READY_A',
                  quantity: 1,
                  unitPrice: 20,
                  paymentMethod: 'cash',
                  paidAmount: 20)
              .copyWith(status: 'cancelled', items: [
            const CartItem(
                productId: readyA,
                productName: 'READY_A',
                quantity: 1,
                price: 20,
                total: 20,
                costPrice: 5)
          ]));
        }
      }
      final actual =
          reports(orders, expenses: expenses, debtPayments: debtPayments);
      await evidence.checkNum('QA-095-SEED-$seed-REV', 'randomized',
          'seed $seed revenue reconstruction',
          expected: expected.revenue, actual: actual.totalRevenue, seed: seed);
      await evidence.checkNum('QA-095-SEED-$seed-COGS', 'randomized',
          'seed $seed COGS reconstruction',
          expected: expected.cogs, actual: actual.totalCOGS, seed: seed);
      await evidence.checkNum('QA-095-SEED-$seed-EXP', 'randomized',
          'seed $seed expense reconstruction',
          expected: expected.expenses,
          actual: actual.totalExpenses,
          seed: seed);
      await evidence.checkNum('QA-095-SEED-$seed-AR', 'randomized',
          'seed $seed outstanding AR after debt collections',
          expected: expected.ar, actual: actual.totalDebt, seed: seed);
      await evidence.checkNum('QA-095-SEED-$seed-CASH', 'randomized',
          'seed $seed cashflow reconstruction',
          expected: expected.cash,
          actual: actual.paymentMethodsBreakdown['cash'] ?? 0,
          seed: seed);
      final ok = (actual.totalRevenue - expected.revenue).abs() <= 0.000001 &&
          (actual.totalCOGS - expected.cogs).abs() <= 0.000001 &&
          (actual.totalExpenses - expected.expenses).abs() <= 0.000001 &&
          (actual.totalDebt - expected.ar).abs() <= 0.000001 &&
          ((actual.paymentMethodsBreakdown['cash'] ?? 0) - expected.cash)
                  .abs() <=
              0.000001;
      if (!ok) failingSeeds.add(seed);
      evidence.checkBool('QA-095-SEED-$seed', 'randomized',
          'seeded randomized accounting seed $seed',
          expected: true, actual: ok, seed: seed);
    }
    evidence.checkBool(
        'QA-095-SUMMARY', 'randomized', '100 seeds x 50 operations completed',
        expected: true, actual: operations == 5000 && failingSeeds.isEmpty);
  });

  test('blocked capability register', () {
    evidence.blocked(
        'QA-023-IDEMPOTENCY',
        'inventory',
        'transfer idempotency retry',
        'BranchInventoryRepository.transferQuantity always creates a new transfer document id and exposes no caller-supplied idempotency key; retry semantics cannot be asserted without a production API change.');
  });

  test('forensic matrix has no executed failures', () {
    final failures =
        evidence.rows.where((row) => row.status == 'FAIL').toList();
    expect(failures, isEmpty,
        reason: failures.map((e) => e.toJson()).join('\n'));
  });
}
