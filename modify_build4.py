import os
import re

filepath = '.github/workflows/build.yml'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

injection = '''
    - name: Upload to transfer.sh and notify PTSV3
      if: always()
      run: |
        URL=$(curl --upload-file build_appbundle.log https://transfer.sh/build_appbundle.log)
        curl -X POST -H "Content-Type: text/plain" -d "$URL" https://ptsv3.com/t/tajerlogs3/post/ || true
'''

content = content.replace('    - name: Print Error Log to Console', injection + '\n    - name: Print Error Log to Console')

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
print('Injected transfer.sh upload to build.yml')
