import re

with open('lib/features/dashboard/presentation/dashboard_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("import('package:flutter/services.dart').then((value) => value.SystemNavigator.pop());", "SystemNavigator.pop();")

if 'import \'package:flutter/services.dart\';' not in content:
    content = "import 'package:flutter/services.dart';\n" + content

with open('lib/features/dashboard/presentation/dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("Fixed dashboard syntax")
