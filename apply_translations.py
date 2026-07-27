import os
import re
import json

arb_ar = {}
with open('extracted.json', 'r', encoding='utf-8') as f:
    arb_ar = json.load(f)

# reverse mapping
ar_to_key = {v: k for k, v in arb_ar.items()}

def process_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    new_content = content
    # Replace exact strings with AppLocalizations.of(context)!.key
    for ar, key in ar_to_key.items():
        if f"'{ar}'" in new_content:
            new_content = new_content.replace(f"'{ar}'", f"AppLocalizations.of(context)!.{key}")
        if f'"{ar}"' in new_content:
            new_content = new_content.replace(f'"{ar}"', f"AppLocalizations.of(context)!.{key}")
            
    if new_content != content:
        if "package:flutter_gen/gen_l10n/app_localizations.dart" not in new_content:
            lines = new_content.split('\n')
            for i, line in enumerate(lines):
                if line.startswith('import '):
                    lines.insert(i, "import 'package:flutter_gen/gen_l10n/app_localizations.dart';")
                    break
            else:
                lines.insert(0, "import 'package:flutter_gen/gen_l10n/app_localizations.dart';")
            new_content = '\n'.join(lines)
            
        # VERY crude const removal to allow AppLocalizations
        new_content = re.sub(r'const\s+(Text|SnackBar|AlertDialog|Center|Padding|SizedBox|Icon|Row|Column|ListTile|Drawer|Container|Align|Positioned|Expanded|Flexible|Card|Divider|CircleAvatar|FloatingActionButton)', r'\1', new_content)
        new_content = re.sub(r'const\s+\[', r'[', new_content)
        new_content = re.sub(r'const\s+\(', r'(', new_content)
        new_content = re.sub(r'const\s+EdgeInsets', r'EdgeInsets', new_content)
        new_content = re.sub(r'const\s+TextStyle', r'TextStyle', new_content)

        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"Updated {filepath}")

for root, dirs, files in os.walk('lib'):
    for file in files:
        if file.endswith('.dart'):
            process_file(os.path.join(root, file))
