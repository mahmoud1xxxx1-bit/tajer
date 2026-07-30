import os
import re

filepath = '.github/workflows/build.yml'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

injection = '''
    - name: Print Error Log to Console
      if: always()
      run: |
        echo "============== ERROR LOG START =============="
        cat build_appbundle.log | tail -n 150
        echo "============== ERROR LOG END =============="
'''

content = content.replace('    - name: Upload Error Logs', injection + '\n    - name: Upload Error Logs')

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
print('Injected Print Error Log to build.yml')
