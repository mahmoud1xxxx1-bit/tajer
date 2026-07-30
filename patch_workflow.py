import os

files = ['.github/workflows/flutter_build.yml', '.github/workflows/build.yml']

for fp in files:
    if os.path.exists(fp):
        with open(fp, 'r', encoding='utf-8') as f:
            content = f.read()
        content = content.replace('> build_apk.log 2>&1', '')
        content = content.replace('> build_appbundle.log 2>&1', '')
        with open(fp, 'w', encoding='utf-8') as f:
            f.write(content)
print('Patched workflows to show logs in console')
