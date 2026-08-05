import re
with open('lib/features/orders/presentation/order_details_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("\\'", "'")

with open('lib/features/orders/presentation/order_details_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)

with open('lib/features/customers/presentation/customers_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()
content = content.replace("import 'package:tajer/l10n/app_localizations.dart';", "import 'package:flutter_gen/gen_l10n/app_localizations.dart';")
with open('lib/features/customers/presentation/customers_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
    
with open('lib/features/customers/presentation/add_customer_dialog.dart', 'r', encoding='utf-8') as f:
    content = f.read()
content = content.replace("import 'package:tajer/l10n/app_localizations.dart';", "import 'package:flutter_gen/gen_l10n/app_localizations.dart';")
with open('lib/features/customers/presentation/add_customer_dialog.dart', 'w', encoding='utf-8') as f:
    f.write(content)

with open('lib/features/suppliers/presentation/suppliers_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()
content = content.replace("import 'package:tajer/l10n/app_localizations.dart';", "import 'package:flutter_gen/gen_l10n/app_localizations.dart';")
with open('lib/features/suppliers/presentation/suppliers_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
