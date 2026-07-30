import os
import re

files_to_fix = [
    'lib/features/categories/presentation/categories_screen.dart',
    'lib/features/customers/presentation/add_customer_dialog.dart',
    'lib/features/expenses/presentation/expenses_screen.dart',
    'lib/features/orders/presentation/add_order_dialog.dart',
    'lib/features/products/presentation/add_product_dialog.dart',
    'lib/features/suppliers/presentation/suppliers_screen.dart'
]

for file_path in files_to_fix:
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Replace specific merchantId assignments
    # In add_product_dialog and add_customer_dialog:
    # merchantId: isEditing ? widget.productToEdit!.merchantId : user.uid
    # We want: merchantId: isEditing ? widget.productToEdit!.merchantId : (appUser?.merchantId ?? user.uid)
    content = re.sub(
        r'merchantId:\s*isEditing\s*\?\s*(widget\.\w+\!\.merchantId)\s*:\s*user\.uid',
        r'merchantId: isEditing ? \1 : (ref.read(appUserProvider).value?.merchantId ?? user.uid)',
        content
    )

    # In other screens:
    # merchantId: user.uid,
    # We want: merchantId: ref.read(appUserProvider).value?.merchantId ?? user.uid,
    content = re.sub(
        r'merchantId:\s*user\.uid,',
        r'merchantId: ref.read(appUserProvider).value?.merchantId ?? user.uid,',
        content
    )

    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)

print("Fixed merchantId in all dialogs")
