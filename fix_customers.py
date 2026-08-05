file = 'lib/features/customers/presentation/customers_screen.dart'
with open(file, 'r', encoding='utf-8') as f:
    content = f.read()

# Fix const PopupMenuItem issue
content = content.replace('const PopupMenuItem(', 'PopupMenuItem(')
content = content.replace('const Text(l10n', 'Text(l10n')

# Fix nullability
content = content.replace('l10n.byCreator(customer.creatorName)', 'l10n.byCreator(customer.creatorName ?? "")')

with open(file, 'w', encoding='utf-8') as f:
    f.write(content)
print('customers_screen fixed!')
