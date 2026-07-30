import urllib.request
import json
import sys

req = urllib.request.Request('https://api.github.com/repos/mahmoud1xxxx1-bit/tajer/actions/runs?per_page=1')
req.add_header('Accept', 'application/vnd.github.v3+json')
try:
    with urllib.request.urlopen(req) as response:
        data = json.loads(response.read())
        if data['workflow_runs']:
            run = data['workflow_runs'][0]
            print(f"Status: {run['status']}, Conclusion: {run['conclusion']}")
            if run['conclusion'] == 'failure':
                print(f"URL: {run['html_url']}")
        else:
            print("No runs found")
except Exception as e:
    print(f"Error: {e}")
