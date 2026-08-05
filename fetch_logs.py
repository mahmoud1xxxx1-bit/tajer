import urllib.request
import zipfile
import io
import re

repo = 'mahmoud1xxxx1-bit/tajer'
run_id = '30979640628'
url = f'https://api.github.com/repos/{repo}/actions/runs/{run_id}/logs'

try:
    req = urllib.request.Request(url)
    with urllib.request.urlopen(req) as response:
        zip_data = response.read()
    
    with zipfile.ZipFile(io.BytesIO(zip_data)) as z:
        for filename in z.namelist():
            if 'Build' in filename or 'build' in filename.lower():
                content = z.read(filename).decode('utf-8', errors='replace')
                # Find compilation errors
                lines = content.split('\n')
                for i, line in enumerate(lines):
                    if 'Error: ' in line or 'Exception: ' in line or 'compiler message:' in line:
                        print(f"[{filename}] Line {i}: {line.strip()}")
                        # Print context
                        for j in range(max(0, i-5), min(len(lines), i+6)):
                            print(f"  {lines[j].strip()}")
                        print("-" * 50)
except Exception as e:
    print('Failed to fetch logs:', e)
