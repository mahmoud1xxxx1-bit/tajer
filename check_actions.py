import urllib.request
import json
import sys

url = "https://api.github.com/repos/mahmoud1xxxx1-bit/tajer/actions/runs"

req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
try:
    with urllib.request.urlopen(req) as response:
        data = json.loads(response.read().decode())
        if 'workflow_runs' in data and len(data['workflow_runs']) > 0:
            run = data['workflow_runs'][0]
            print(f"Status: {run['status']}")
            print(f"Conclusion: {run['conclusion']}")
            print(f"URL: {run['html_url']}")
            
            if run['status'] == 'completed' and run['conclusion'] == 'failure':
                jobs_url = run['jobs_url']
                req2 = urllib.request.Request(jobs_url, headers={'User-Agent': 'Mozilla/5.0'})
                with urllib.request.urlopen(req2) as res2:
                    jobs_data = json.loads(res2.read().decode())
                    for job in jobs_data.get('jobs', []):
                        if job['conclusion'] == 'failure':
                            print(f"Failed job: {job['name']} ({job['html_url']})")
        else:
            print("No runs found")
except Exception as e:
    print(f"Error: {e}")
