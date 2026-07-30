# -*- coding: utf-8 -*-
import urllib.request
import re

try:
    url = 'https://ptsv3.com/t/tajerlogs/'
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    with urllib.request.urlopen(req) as response:
        html = response.read().decode('utf-8')
        match = re.search(r'href="(.*?/d/.*?)"', html)
        if match:
            post_url = 'https://ptsv3.com' + match.group(1)
            print("Found post:", post_url)
            req2 = urllib.request.Request(post_url, headers={'User-Agent': 'Mozilla/5.0'})
            with urllib.request.urlopen(req2) as res2:
                html2 = res2.read().decode('utf-8')
                m2 = re.search(r'<pre.*?>(.*?)</pre>', html2, re.DOTALL)
                if m2:
                    text = m2.group(1)
                    for line in text.split('\n'):
                        if 'error' in line.lower() or 'warning' in line.lower() or 'Exception' in line:
                            print(line.strip())
                else:
                    print("No pre block")
        else:
            print("No posts found")
except Exception as e:
    print(f"Error: {e}")
