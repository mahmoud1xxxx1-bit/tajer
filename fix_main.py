with open('lib/main.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("import('package:wakelock_plus/wakelock_plus.dart').then((WakelockPlus) => WakelockPlus.WakelockPlus.enable());", "WakelockPlus.enable();")

if 'package:wakelock_plus/wakelock_plus.dart' not in content:
    content = "import 'package:wakelock_plus/wakelock_plus.dart';\n" + content

with open('lib/main.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print('Fixed main.dart')
