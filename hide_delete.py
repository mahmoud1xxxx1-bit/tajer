import re

file1 = 'lib/features/orders/presentation/order_details_screen.dart'
with open(file1, 'r', encoding='utf-8') as f:
    content1 = f.read()

# Add appUserProvider if missing
if "import '../../authentication/data/auth_repository.dart';" not in content1:
    content1 = "import '../../authentication/data/auth_repository.dart';\n" + content1

# In build method
target1 = "final storeProfile = ref.watch(storeProfileProvider).value;"
if "final isEmployee = ref.watch(appUserProvider).value?.role == 'employee';" not in content1:
    content1 = content1.replace(target1, target1 + "\n    final isEmployee = ref.watch(appUserProvider).value?.role == 'employee';")

# Find the delete button
# It looks like:
# IconButton(
#   icon: const Icon(Icons.delete_outline, color: Colors.red),
#   onPressed: () => _deleteOrder(isAr),
# )

button_pattern = r"(IconButton\(\s*icon: const Icon\(Icons\.delete_outline.*?onPressed: \(\) => _deleteOrder\(isAr\),\s*\))"
content1 = re.sub(button_pattern, r"if (!isEmployee) \1", content1, flags=re.DOTALL)

with open(file1, 'w', encoding='utf-8') as f:
    f.write(content1)

# Now orders_screen.dart
file2 = 'lib/features/orders/presentation/orders_screen.dart'
with open(file2, 'r', encoding='utf-8') as f:
    content2 = f.read()

if "import '../../authentication/data/auth_repository.dart';" not in content2:
    content2 = "import '../../authentication/data/auth_repository.dart';\n" + content2

target2 = "Widget build(BuildContext context) {"
if "final isEmployee = ref.watch(appUserProvider).value?.role == 'employee';" not in content2:
    content2 = content2.replace(target2, target2 + "\n    final isEmployee = ref.watch(appUserProvider).value?.role == 'employee';")

# Hide delete in orders_screen.dart too?
# wait, orders_screen might have a slideable delete or a delete button on each item.
# let's just write content1 back for now and inspect orders_screen.dart separately.
