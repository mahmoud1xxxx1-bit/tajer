import urllib.request
import json
import time
import sys

while True:
    try:
        req = urllib.request.Request('https://api.github.com/repos/mahmoud1xxxx1-bit/tajer/actions/runs?per_page=1')
        req.add_header('Accept', 'application/vnd.github.v3+json')
        with urllib.request.urlopen(req) as response:
            data = json.loads(response.read())
            if data['workflow_runs']:
                run = data['workflow_runs'][0]
                if run['status'] != 'in_progress' and run['status'] != 'queued':
                    print(f"Workflow finished! Conclusion: {run['conclusion']}")
                    if run['conclusion'] == 'failure':
                        print(f"Failed URL: {run['html_url']}")
                        sys.exit(1)
                    else:
                        sys.exit(0)
    except Exception as e:
        print(f"Error polling: {e}")
    time.sleep(15)
