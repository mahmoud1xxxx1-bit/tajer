import os

filepath = '.github/workflows/flutter_build.yml'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# First, remove any previous > build_apk.log 2>&1 just in case, and rewrite the step
content = content.replace('flutter build apk --release > build_apk.log 2>&1', 'flutter build apk --release')
content = content.replace('flutter build apk --release', 'flutter build apk --release > build_apk.log 2>&1')

injection = '''
      - name: Push Logs
        if: always()
        run: |
          git config --global user.name "github-actions[bot]"
          git config --global user.email "github-actions[bot]@users.noreply.github.com"
          git checkout -b debug-logs-123
          git add build_apk.log analyze_log.txt || true
          git commit -m "chore: push logs" || true
          git push origin debug-logs-123 --force || true
'''

content = content.replace('      - name: Build App Bundle', injection + '\n      - name: Build App Bundle')

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
print('Injected Push Logs')
