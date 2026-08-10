import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajer/features/dashboard/presentation/branch_catalog_migration_gate.dart';

void main() {
  testWidgets('loading and error states never mount the ready catalog tree',
      (tester) async {
    var readyBuilds = 0;
    var retries = 0;

    Widget app(AsyncValue<void> state, {Locale locale = const Locale('en')}) {
      return MaterialApp(
        locale: locale,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: const [Locale('en'), Locale('ar')],
        home: BranchCatalogMigrationGate(
          state: state,
          onRetry: () => retries++,
          readyBuilder: (_) {
            readyBuilds++;
            return const Scaffold(
              body: Text('CATALOG_READY_SENTINEL'),
            );
          },
        ),
      );
    }

    await tester.pumpWidget(app(const AsyncLoading<void>()));
    expect(find.byKey(const Key('branch-catalog-migration-loading')),
        findsOneWidget);
    expect(find.text('CATALOG_READY_SENTINEL'), findsNothing);
    expect(readyBuilds, 0);

    await tester.pumpWidget(
      app(AsyncError<void>(
          StateError('permission-denied'), StackTrace.current)),
    );
    expect(find.byKey(const Key('branch-catalog-migration-error')),
        findsOneWidget);
    expect(find.textContaining('permission-denied'), findsNothing);
    expect(find.textContaining('Bad state'), findsNothing);
    expect(find.textContaining('StateError'), findsNothing);
    expect(find.text('CATALOG_READY_SENTINEL'), findsNothing);
    expect(readyBuilds, 0);

    await tester.tap(find.byKey(const Key('branch-catalog-migration-retry')));
    expect(retries, 1);

    await tester.pumpWidget(app(const AsyncData<void>(null)));
    expect(find.byKey(const Key('branch-catalog-migration-ready')),
        findsOneWidget);
    expect(find.text('CATALOG_READY_SENTINEL'), findsOneWidget);
    expect(readyBuilds, 1);
  });

  testWidgets('error copy is localized and does not expose technical details',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: const [Locale('en'), Locale('ar')],
        home: BranchCatalogMigrationGate(
          state: AsyncError<void>(
            FirebaseExceptionForTest(),
            StackTrace.current,
          ),
          onRetry: () {},
          readyBuilder: (_) => const SizedBox.shrink(),
        ),
      ),
    );

    expect(
      find.text(
          '\u062a\u0639\u0630\u0631 \u0625\u0643\u0645\u0627\u0644 \u062a\u0647\u064a\u0626\u0629 \u0628\u064a\u0627\u0646\u0627\u062a \u0627\u0644\u0641\u0631\u0648\u0639. \u0644\u0645 \u064a\u062a\u0645 \u062a\u063a\u064a\u064a\u0631 \u0628\u064a\u0627\u0646\u0627\u062a\u0643. \u062d\u0627\u0648\u0644 \u0645\u0631\u0629 \u0623\u062e\u0631\u0649.'),
      findsOneWidget,
    );
    expect(find.textContaining('permission-denied'), findsNothing);
  });
}

class FirebaseExceptionForTest implements Exception {
  @override
  String toString() => '[cloud_firestore/permission-denied]';
}
