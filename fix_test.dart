import 'dart:io';

void main() {
  final file = File('test/accounting_notebook_integration_test.dart');
  var content = file.readAsStringSync();

  content = content.replaceAll(
    "NotebookAccount(id: 'acc1', name: 'Cash', balance:",
    "NotebookAccount(id: 'acc1', name: 'Cash', type: 'asset', balance:"
  );

  content = content.replaceAll(
    "NotebookAccount(id: 'acc2', name: 'Bank', balance:",
    "NotebookAccount(id: 'acc2', name: 'Bank', type: 'asset', balance:"
  );

  file.writeAsStringSync(content);
}
