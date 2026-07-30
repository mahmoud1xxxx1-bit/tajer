import os
import re

filepath = '.github/workflows/flutter_build.yml'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('run: flutter build apk --release', 'run: flutter build apk --release > build_apk.log 2>&1')
content = content.replace('run: flutter build appbundle --release', 'run: flutter build appbundle --release')

injection = '''
      - name: Send Build Log
        if: always()
        run: curl -X POST -H "Content-Type: text/plain" -d @build_apk.log https://ptsv3.com/t/tajerlogs/post/ || true
'''

content = content.replace('      - name: Build AppBundle', injection + '\n      - name: Build AppBundle')

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
