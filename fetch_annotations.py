import urllib.request
import json
import sys

run_id = 30301465623
jobs_url = f"https://api.github.com/repos/mahmoud1xxxx1-bit/tajer/actions/runs/{run_id}/jobs"

try:
    req = urllib.request.Request(jobs_url, headers={'User-Agent': 'Mozilla/5.0'})
    with urllib.request.urlopen(req) as res:
        jobs_data = json.loads(res.read().decode())
        for job in jobs_data.get('jobs', []):
            if job['conclusion'] == 'failure':
                print(f"Job failed: {job['name']}")
                check_run_id = job['id']
                annotations_url = f"https://api.github.com/repos/mahmoud1xxxx1-bit/tajer/check-runs/{check_run_id}/annotations"
                
                req2 = urllib.request.Request(annotations_url, headers={'User-Agent': 'Mozilla/5.0'})
                with urllib.request.urlopen(req2) as res2:
                    annotations = json.loads(res2.read().decode())
                    for ann in annotations:
                        print(f"Error in {ann['path']} line {ann['start_line']}: {ann['message']}")
except Exception as e:
    print(f"Error: {e}")
