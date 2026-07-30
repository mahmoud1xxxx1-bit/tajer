import os

filepath = '.github/workflows/flutter_build.yml'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace the Push Logs step with an Upload Artifact step
import re
content = re.sub(r'      - name: Push Logs.*?git push origin debug-logs-123 --force \|\| true', '''      - name: Upload Error Logs
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: error-logs
          path: |
            build_apk.log
            analyze_log.txt''', content, flags=re.DOTALL)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
print('Injected Upload Error Logs')
