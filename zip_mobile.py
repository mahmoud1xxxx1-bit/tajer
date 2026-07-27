import os
import zipfile

def zipdir(path, ziph):
    for root, dirs, files in os.walk(path):
        dirs[:] = [d for d in dirs if d not in ('node_modules', '.git', 'build', '.dart_tool', 'tajer-admin-web', 'android/.gradle')]
        for file in files:
            file_path = os.path.join(root, file)
            # Avoid zipping the zip file itself and some other large unnecessary files
            if file.endswith('.zip') or file.endswith('.aab') or file.endswith('.apk'):
                continue
            arcname = os.path.relpath(file_path, start=os.path.dirname(path))
            ziph.write(file_path, arcname)

if __name__ == '__main__':
    src = r'c:\Users\loved\gamex1\tajer'
    dst = r'c:\Users\loved\gamex1\tajer-mobile.zip'
    with zipfile.ZipFile(dst, 'w', zipfile.ZIP_DEFLATED) as zipf:
        zipdir(src, zipf)
    print("Mobile app zipping completed.")
