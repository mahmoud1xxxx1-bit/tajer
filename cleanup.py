import os
import re

for filepath in ['.github/workflows/build.yml', '.github/workflows/flutter_build.yml']:
    if not os.path.exists(filepath): continue
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Remove all the debug steps we injected
    content = re.sub(r'\s+- name: Upload to transfer.sh.*?(?=\n\s+- name: |\Z)', '', content, flags=re.DOTALL)
    content = re.sub(r'\s+- name: Print Error Log.*?(?=\n\s+- name: |\Z)', '', content, flags=re.DOTALL)
    content = re.sub(r'\s+- name: Upload Error Logs.*?(?=\n\s+- name: |\Z)', '', content, flags=re.DOTALL)
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

print('Cleaned up debug steps')
