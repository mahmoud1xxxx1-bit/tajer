import os

repo_files = [
    'lib/features/categories/data/category_repository.dart',
    'lib/features/customers/data/customer_repository.dart',
    'lib/features/employees/data/employee_repository.dart',
    'lib/features/expenses/data/expense_repository.dart',
    'lib/features/inventory_log/data/inventory_log_repository.dart',
    'lib/features/notifications/data/notification_repository.dart',
    'lib/features/orders/data/order_repository.dart',
    'lib/features/products/data/product_repository.dart',
    'lib/features/suppliers/data/supplier_repository.dart',
]

for file in repo_files:
    if os.path.exists(file):
        with open(file, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Replace the user watch
        content = content.replace(
            'final user = ref.watch(authRepositoryProvider).currentUser;',
            'final appUser = ref.watch(appUserProvider).value;'
        )
        content = content.replace(
            'if (user == null) return null;',
            'if (appUser == null) return null;'
        )
        content = content.replace(
            'if (user == null) return const Stream.empty();',
            'if (appUser == null) return const Stream.empty();'
        )
        content = content.replace(
            'return CategoryRepository(FirebaseFirestore.instance, user.uid);',
            'return CategoryRepository(FirebaseFirestore.instance, appUser.merchantId ?? appUser.id);'
        )
        content = content.replace(
            'return CustomerRepository(FirebaseFirestore.instance, user.uid);',
            'return CustomerRepository(FirebaseFirestore.instance, appUser.merchantId ?? appUser.id);'
        )
        content = content.replace(
            'return EmployeeRepository(FirebaseFirestore.instance, user.uid);',
            'return EmployeeRepository(FirebaseFirestore.instance, appUser.merchantId ?? appUser.id);'
        )
        content = content.replace(
            'return ExpenseRepository(FirebaseFirestore.instance, user.uid);',
            'return ExpenseRepository(FirebaseFirestore.instance, appUser.merchantId ?? appUser.id);'
        )
        content = content.replace(
            'return InventoryLogRepository(FirebaseFirestore.instance, user.uid);',
            'return InventoryLogRepository(FirebaseFirestore.instance, appUser.merchantId ?? appUser.id);'
        )
        content = content.replace(
            'return NotificationRepository(FirebaseFirestore.instance, user.uid);',
            'return NotificationRepository(FirebaseFirestore.instance, appUser.merchantId ?? appUser.id);'
        )
        content = content.replace(
            'return OrderRepository(FirebaseFirestore.instance, user.uid);',
            'return OrderRepository(FirebaseFirestore.instance, appUser.merchantId ?? appUser.id);'
        )
        content = content.replace(
            'return repository.queryProducts(user.uid).snapshots().map(',
            'return repository.queryProducts(appUser.merchantId ?? appUser.id).snapshots().map('
        )
        content = content.replace(
            'return SupplierRepository(FirebaseFirestore.instance, user.uid);',
            'return SupplierRepository(FirebaseFirestore.instance, appUser.merchantId ?? appUser.id);'
        )

        with open(file, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f'Updated {file}')
