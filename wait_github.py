import urllib.request
import json
import time
import sys

repo = 'mahmoud1xxxx1-bit/tajer'
url = f'https://api.github.com/repos/{repo}/actions/runs'

print('Waiting for GitHub Actions (commit 546d572)...')

for _ in range(60): # 60 * 10 = 600 seconds = 10 minutes max
    try:
        req = urllib.request.Request(url, headers={'Accept': 'application/vnd.github.v3+json'})
        with urllib.request.urlopen(req) as response:
            data = json.loads(response.read().decode())
            
        run = next((r for r in data['workflow_runs'] if r['head_sha'].startswith('546d572')), None)
        if run:
            if run['status'] == 'completed':
                print(f"\nFINISHED! Conclusion: {run['conclusion']}")
                sys.exit(0)
            else:
                sys.stdout.write('.')
                sys.stdout.flush()
        else:
            print('\nRun not found yet.')
    except Exception as e:
        print(f'\nError: {e}')
    time.sleep(10)
