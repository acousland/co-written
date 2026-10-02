#!/usr/bin/env python3
import sys
import time
import urllib.request
import xml.etree.ElementTree as ET

tree = ET.parse(sys.argv[1])
urls = list(dict.fromkeys(element.get("url") for element in tree.getroot().iter("enclosure")))
for url in urls:
    for attempt in range(8):
        try:
            request = urllib.request.Request(url, headers={"Range": "bytes=0-0"})
            with urllib.request.urlopen(request, timeout=20) as response:
                if response.status in (200, 206):
                    break
        except Exception:
            if attempt == 7:
                raise SystemExit(f"Download not available; leave feed unpublished: {url}")
            time.sleep(5)
print("All feed downloads are reachable")
