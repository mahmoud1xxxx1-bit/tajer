import urllib.request
import json
import sys
import zipfile
import io

url = "https://api.github.com/repos/mahmoud1xxxx1-bit/tajer/actions/jobs/90090608208/logs"

try:
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    with urllib.request.urlopen(req) as response:
        content = response.read().decode('utf-8')
        # Print the last 50 lines of the log which usually contains the compiler errors
        lines = content.splitlines()
        for line in lines[-50:]:
            print(line)
except Exception as e:
    print(f"Error: {e}")
