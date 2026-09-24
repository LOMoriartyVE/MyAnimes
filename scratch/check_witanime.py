import urllib.request
import re

url = 'https://witanime.site/'
req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'})
try:
    with urllib.request.urlopen(req) as resp:
        html = resp.read().decode('utf-8', 'ignore')
        eps = re.findall(r'href=[\"\'](https://witanime\.site/episode/[^\"\']+)[\"\']', html)
        print('Found episodes:', eps[:3])
        if eps:
            ep_url = eps[0]
            print('Fetching:', ep_url)
            req2 = urllib.request.Request(ep_url, headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'})
            with urllib.request.urlopen(req2) as resp2:
                ep_html = resp2.read().decode('utf-8', 'ignore')
                # Find download section
                pos = ep_html.find('تحميل')
                if pos != -1:
                    print('Download section preview:')
                    print(ep_html[pos:pos+4000])
                else:
                    print('Download keyword not found')
except Exception as e:
    print('Error:', e)
