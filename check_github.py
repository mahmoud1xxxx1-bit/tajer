import urllib.request
import json

repo = 'mahmoud1xxxx1-bit/tajer'
url = f'https://api.github.com/repos/{repo}/actions/runs'

req = urllib.request.Request(url, headers={'Accept': 'application/vnd.github.v3+json'})
try:
    with urllib.request.urlopen(req) as response:
        data = json.loads(response.read().decode())
        
    for run in data['workflow_runs'][:3]:
        print(f"Run ID: {run['id']}, Commit: {run['head_sha'][:7]}, Status: {run['status']}, Conclusion: {run['conclusion']}")
        print(f"Message: {run['head_commit']['message']}")
        print("-" * 40)
except Exception as e:
    print('Error:', e)
