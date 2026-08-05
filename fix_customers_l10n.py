import re

with open('lib/features/customers/presentation/customers_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('void _showMoveToFolderDialog(String customerId) {', 'void _showMoveToFolderDialog(String customerId) {\n    final l10n = AppLocalizations.of(context)!;')
content = content.replace('void _showPayDebtDialog(Customer customer) {', 'void _showPayDebtDialog(Customer customer) {\n    final l10n = AppLocalizations.of(context)!;')
content = content.replace('Future<void> _exportToExcel() async {', 'Future<void> _exportToExcel() async {\n    final l10n = AppLocalizations.of(context)!;')

with open('lib/features/customers/presentation/customers_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
