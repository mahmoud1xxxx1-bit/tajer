import os
import re

filepath = '.github/workflows/build.yml'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('run: flutter build appbundle --release', 'run: flutter build appbundle --release > build_appbundle.log 2>&1')

injection = '''
    - name: Send Build Log
      if: always()
      run: curl -X POST -H "Content-Type: text/plain" -d @build_appbundle.log https://ptsv3.com/t/tajerlogs2/post/ || true
'''

content = content.replace('    - name: Upload Artifact', injection + '\n    - name: Upload Artifact')

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
print('Injected PTSV3 webhook into build.yml')
