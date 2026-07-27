import os
import zipfile

def zipdir(path, ziph):
    for root, dirs, files in os.walk(path):
        # Exclude node_modules and .git
        dirs[:] = [d for d in dirs if d not in ('node_modules', '.git')]
        for file in files:
            file_path = os.path.join(root, file)
            arcname = os.path.relpath(file_path, start=os.path.dirname(path))
            ziph.write(file_path, arcname)

if __name__ == '__main__':
    src = r'c:\Users\loved\gamex1\tajer\tajer-admin-web'
    dst = r'c:\Users\loved\gamex1\tajer-admin-web.zip'
    with zipfile.ZipFile(dst, 'w', zipfile.ZIP_DEFLATED) as zipf:
        zipdir(src, zipf)
    print("Zipping completed.")
