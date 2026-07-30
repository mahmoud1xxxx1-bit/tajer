import os
import re

filepath = '.github/workflows/build.yml'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

content = re.sub(r'    - name: Send Build Log.*?curl -X POST -H "Content-Type: text/plain" -d @build_appbundle.log https://ptsv3.com/t/tajerlogs2/post/ \|\| true', '''    - name: Upload Error Logs
      if: always()
      uses: actions/upload-artifact@v4
      with:
        name: error-logs
        path: |
          build_appbundle.log''', content, flags=re.DOTALL)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
print('Injected Upload Error Logs to build.yml')
