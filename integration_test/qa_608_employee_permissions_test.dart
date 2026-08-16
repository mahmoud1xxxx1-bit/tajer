import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tajer/firebase_options.dart';
import 'package:tajer/features/authentication/data/auth_repository.dart';
import 'package:tajer/features/employees/presentation/employee_permissions_screen.dart';

bool _emulatorsConfigured = false;

Future<String> _loginMerchant() async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }
  if (!_emulatorsConfigured) {
    FirebaseFirestore.instance.useFirestoreEmulator('10.0.2.2', 8080);
    await FirebaseAuth.instance.useAuthEmulator('10.0.2.2', 9099);
    _emulatorsConfigured = true;
  }
  final auth = FirebaseAuth.instance;
  if (auth.currentUser != null) return auth.currentUser!.uid;
  try {
    await auth.signInWithEmailAndPassword(email: 'qa-permissions@test.local', password: 'password123');
  } catch (_) {
    try {
      await auth.createUserWithEmailAndPassword(email: 'qa-permissions@test.local', password: 'password123');
    } catch (_) {
      await auth.signInWithEmailAndPassword(email: 'qa-permissions@test.local', password: 'password123');
    }
  }
  final uid = auth.currentUser!.uid;
  await FirebaseFirestore.instance.collection('users').doc(uid).set({
    'id': uid,
    'name': 'QA Merchant',
    'email': 'qa-permissions@test.local',
    'role': 'merchant',
    'plan': 'premium',
    'isAnonymous': false,
    'createdAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
  return uid;
}

Future<void> _pumpUntil(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 80; i++) {
    await tester.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw StateError('Widget not found: ${finder.description}');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('TEST 8/34 - employee permission saves from #608 top Save button and survives re-entry', (tester) async {
    final merchantUid = await _loginMerchant();
    final db = FirebaseFirestore.instance;
    final authRepo = AuthRepository(FirebaseAuth.instance, db);

    const employeeUid = 'qa608_employee_permissions';
    const initialPermissions = <String, bool>{
      'can_manage_products': false,
      'can_view_cost': false,
      'can_manage_inventory': false,
      'can_create_orders': false,
      'can_cancel_orders': false,
      'can_sell_on_credit': false,
      'can_manage_customers': false,
      'can_receive_payments': false,
      'can_manage_expenses': false,
      'can_view_reports': false,
      'can_view_all_orders': false,
      'can_access_accounting_notebook': false,
    };

    final employeeData = <String, dynamic>{
      'name': 'QA Employee',
      'pin': '2468',
      'permissions': initialPermissions,
      'createdAt': FieldValue.serverTimestamp(),
    };
    await db.collection('users').doc(merchantUid).collection('employees').doc(employeeUid).set(employeeData);
    await db.collection('users').doc(employeeUid).set({
      'id': employeeUid,
      'name': 'QA Employee',
      'role': 'employee',
      'merchantId': merchantUid,
      'plan': 'employee',
      'permissions': initialPermissions,
      'createdAt': FieldValue.serverTimestamp(),
    });

    Future<Map<String, dynamic>> readEmployeeSubdoc() async =>
        (await db.collection('users').doc(merchantUid).collection('employees').doc(employeeUid).get()).data()!;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(authRepo),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [],
          home: EmployeePermissionsScreen(
            employeeUid: employeeUid,
            initialData: {
              'name': 'QA Employee',
              'pin': '2468',
              'permissions': initialPermissions,
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The requested #608 behavior specifically uses the Save button in the app bar.
    final switches = find.byType(Switch);
    expect(switches.evaluate().length, 12);
    final notebookSwitch = switches.at(11);
    expect((tester.widget<Switch>(notebookSwitch)).value, false);
    await tester.tap(notebookSwitch);
    await tester.pump();
    expect((tester.widget<Switch>(notebookSwitch)).value, true);

    final save = find.text('Save');
    await _pumpUntil(tester, save);
    await tester.tap(save.first);
    await tester.pumpAndSettle();

    final subdoc = await readEmployeeSubdoc();
    final rootdoc = (await db.collection('users').doc(employeeUid).get()).data()!;
    final subPerms = Map<String, dynamic>.from(subdoc['permissions'] as Map);
    final rootPerms = Map<String, dynamic>.from(rootdoc['permissions'] as Map);
    expect(subPerms['can_access_accounting_notebook'], true,
        reason: 'Merchant employee subdocument must persist notebook access');
    expect(rootPerms['can_access_accounting_notebook'], true,
        reason: 'Employee root user document must persist notebook access');

    // Re-enter using the actual stored data, matching the user contract.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(authRepo)],
        child: MaterialApp(
          locale: const Locale('en'),
          home: EmployeePermissionsScreen(
            employeeUid: employeeUid,
            initialData: {
              'name': subdoc['name'],
              'pin': subdoc['pin'],
              'permissions': subPerms,
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final switchesAfter = find.byType(Switch);
    expect(switchesAfter.evaluate().length, 12);
    expect((tester.widget<Switch>(switchesAfter.at(11))).value, true,
        reason: 'After re-entry the saved accounting notebook permission must still be ON');
  });
}
