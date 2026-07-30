import urllib.request
import json
import zipfile
import io

try:
    req = urllib.request.Request('https://api.github.com/repos/mahmoud1xxxx1-bit/tajer/actions/runs/30584449935/jobs')
    req.add_header('Accept', 'application/vnd.github.v3+json')
    with urllib.request.urlopen(req) as response:
        data = json.loads(response.read())
        for job in data['jobs']:
            if job['conclusion'] == 'failure':
                job_id = job['id']
                print(f"Failed job ID: {job_id}")
                
                # Fetch logs for the failed job
                log_req = urllib.request.Request(f'https://api.github.com/repos/mahmoud1xxxx1-bit/tajer/actions/jobs/{job_id}/logs')
                try:
                    with urllib.request.urlopen(log_req) as log_response:
                        logs = log_response.read().decode('utf-8')
                        print("---------- LOG SNIPPET ----------")
                        # Print last 50 lines containing 'error' or 'Error' or 'Failed'
                        lines = logs.split('\n')
                        err_lines = [l for l in lines if 'error' in l.lower() or 'failed' in l.lower() or 'expected' in l.lower() or 'undefined' in l.lower()]
                        for l in err_lines[-30:]:
                            print(l.strip())
                        print("---------- LAST 30 LINES ----------")
                        for l in lines[-30:]:
                            print(l.strip())
                except urllib.error.HTTPError as e:
                    print(f"Could not fetch logs for job {job_id}: {e}")
                
except Exception as e:
    print(f"Error: {e}")
