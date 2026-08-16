import 'package:flutter_test/flutter_test.dart';
import 'package:tajer/features/accounting_notebook/domain/notebook_person.dart';

void main() {
  group('NotebookPerson legacy data compatibility', () {
    test('parses numeric strings and missing createdAt safely', () {
      final person = NotebookPerson.fromMap({
        'name': 'Legacy Customer',
        'phone': '0500000000',
        'bookId': 'bookA',
        'amountOwedToMe': '125.50',
        'amountIOwe': '25',
        'isArchived': 'false',
      }, 'legacy-1');

      expect(person.name, 'Legacy Customer');
      expect(person.amountOwedToMe, 125.50);
      expect(person.amountIOwe, 25);
      expect(person.netBalance, 100.50);
      expect(person.isArchived, isFalse);
      expect(person.createdAt, isA<DateTime>());
    });

    test('parses old numeric archive flag without throwing', () {
      final person = NotebookPerson.fromMap({
        'name': 'Archived Legacy Person',
        'bookId': 'bookA',
        'amountOwedToMe': 0,
        'amountIOwe': 0,
        'isArchived': 1,
      }, 'legacy-2');

      expect(person.isArchived, isTrue);
    });
  });
}
