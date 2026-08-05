import os
import re

def check_file(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # 1. Check if l10n is used inside a const widget
    if re.search(r'const\s+[a-zA-Z0-9_]+\([^)]*l10n\.', content):
        return 'l10n used inside const'
        
    # 2. Check for missing l10n declaration where l10n is used
    if 'l10n.' in content and 'AppLocalizations.of' not in content and 'import' in content:
        # Some files might receive l10n as a parameter, so we just flag it
        if 'l10n' not in content.split('l10n.')[0]:
            return 'l10n used without being declared'

    return None

for root, _, files in os.walk('lib'):
    for file in files:
        if file.endswith('.dart'):
            err = check_file(os.path.join(root, file))
            if err:
                print(f'{file}: {err}')
