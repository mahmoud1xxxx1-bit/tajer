import os
import re

def check_file(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Find all methods
    # Simple heuristic: look for '{' and keep track of scope level
    
    if 'l10n.' not in content:
        return
        
    lines = content.split('\n')
    scope = 0
    l10n_defined_in_scope = []
    
    for i, line in enumerate(lines):
        # Extremely rudimentary check, just to find glaring issues
        # Actually, let's just do a regex search for methods containing l10n.
        pass

    # A better approach: split by method declarations using a regex.
    # Actually, Dart scope analysis in Python is hard.
    # Let's just find lines with l10n. and look up 20 lines to see if inal l10n or Widget build or AppLocalizations is nearby.
    
    for i, line in enumerate(lines):
        if re.search(r'\bl10n\.', line):
            # Check if l10n is declared within the last 50 lines
            start = max(0, i - 100)
            context_block = '\n'.join(lines[start:i+1])
            if 'final l10n' not in context_block and 'AppLocalizations l10n' not in context_block and 'AppLocalizations?' not in context_block and 'Widget build(BuildContext context, AppLocalizations l10n)' not in context_block:
                print(f'{file_path}:{i+1} might have undefined l10n: {line.strip()}')
                
for root, _, files in os.walk('lib'):
    for file in files:
        if file.endswith('.dart'):
            check_file(os.path.join(root, file))
