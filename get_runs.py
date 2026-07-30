import urllib.request, json
url = 'https://api.github.com/repos/mahmoud1xxxx1-bit/tajer/actions/runs?per_page=30'
req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla'})
response = urllib.request.urlopen(req)
data = json.loads(response.read().decode('utf-8'))
for run in data['workflow_runs']:
    print(f"{run['id']} - {run['status']} - {run['conclusion']} - {run['name']} - {run['head_commit']['message'][:30]}")
