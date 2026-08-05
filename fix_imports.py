import os

wrong_import = "import 'package:flutter_gen/gen_l10n/app_localizations.dart';"
correct_import = "import 'package:tajer/l10n/app_localizations.dart';"

for root, _, files in os.walk('lib'):
    for file in files:
        if file.endswith('.dart'):
            path = os.path.join(root, file)
            with open(path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            if wrong_import in content:
                # Replace all wrong imports with correct import
                content = content.replace(wrong_import, correct_import)
                
            # Now deduplicate correct imports
            if content.count(correct_import) > 1:
                # Keep the first one, remove others
                parts = content.split(correct_import)
                content = parts[0] + correct_import + ''.join(parts[1:])
                
            with open(path, 'w', encoding='utf-8') as f:
                f.write(content)

print('IMPORTS FIXED')
