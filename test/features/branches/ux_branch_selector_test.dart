import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajer/features/branches/presentation/active_branch_selector.dart';
import 'package:tajer/features/branches/presentation/branch_context.dart';
import 'package:tajer/features/branches/data/branch_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  group('F9 UX Branch Selector tests', () {
    testWidgets('ActiveBranchSelector renders correctly in compact mode', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            selectedBranchIdProvider.overrideWith((ref) => 'main'),
            branchesStreamProvider.overrideWith((ref) => Stream.value([])),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  ActiveBranchSelector(compact: true),
                ],
              ),
            ),
          ),
        ),
      );

      // Verify widget builds without error
      expect(find.byType(ActiveBranchSelector), findsOneWidget);
    });
  });
}
