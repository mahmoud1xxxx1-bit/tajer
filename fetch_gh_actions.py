# -*- coding: utf-8 -*-
import urllib.request
import re

url = 'https://github.com/mahmoud1xxxx1-bit/tajer/actions'
req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'})
try:
    with urllib.request.urlopen(req) as response:
        html = response.read().decode('utf-8')
        matches = re.findall(r'href="/mahmoud1xxxx1-bit/tajer/actions/runs/(\d+)"', html)
        if matches:
            run_id = matches[0]
            print(f"Latest run id: {run_id}")
            
            # Now fetch the log URL for the failed job
            # Wait, fetching logs without auth is hard from HTML. 
            # The API endpoint is api.github.com/repos/mahmoud1xxxx1-bit/tajer/actions/runs/{run_id}/jobs
            # Let's try the API, maybe we are NOT rate limited if we use a different user agent?
            api_url = f'https://api.github.com/repos/mahmoud1xxxx1-bit/tajer/actions/runs/{run_id}/jobs'
            api_req = urllib.request.Request(api_url, headers={'User-Agent': 'Mozilla/5.0'})
            try:
                with urllib.request.urlopen(api_req) as api_res:
                    import json
                    data = json.loads(api_res.read().decode('utf-8'))
                    for job in data.get('jobs', []):
                        print(f"Job {job['name']} status: {job['conclusion']}")
            except Exception as e:
                print(f"API Error: {e}")
        else:
            print("No run IDs found")
except Exception as e:
    print(f"HTML Error: {e}")
