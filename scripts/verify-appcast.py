#!/usr/bin/env python3
import sys
import subprocess
from pathlib import Path
from urllib.parse import unquote, urlparse
import xml.etree.ElementTree as ET

path, version, build = sys.argv[1:]
sparkle = "{http://www.andymatuschak.org/xml-namespaces/sparkle}"
items = ET.parse(path).getroot().findall("channel/item")
if not items or items[0].findtext(sparkle + "shortVersionString") != version or items[0].findtext(sparkle + "version") != build:
    raise SystemExit("The feed does not offer the current version/build first")
for item in items:
    for enclosure in [item.find("enclosure"), *item.findall(sparkle + "deltas/enclosure")]:
        if enclosure is None or not enclosure.get(sparkle + "edSignature") or not enclosure.get("url", "").startswith("https://") or int(enclosure.get("length", "0")) <= 0:
            raise SystemExit("An update enclosure is unsigned or invalid")
for enclosure in [items[0].find("enclosure"), *items[0].findall(sparkle + "deltas/enclosure")]:
    filename = unquote(urlparse(enclosure.get("url")).path.rsplit("/", 1)[-1])
    if Path(filename).name != filename:
        raise SystemExit("Invalid update filename")
    archive = Path(path).parent / filename
    if not archive.is_file() or archive.stat().st_size != int(enclosure.get("length")):
        raise SystemExit(f"Missing update archive or incorrect size: {filename}")
    subprocess.run([".build/artifacts/sparkle/Sparkle/bin/sign_update", "--account", "co-written", "--verify",
        str(archive), enclosure.get(sparkle + "edSignature")], check=True)
print(f"Verified {len(items)} signed update(s), {len(items[0].findall(sparkle + 'deltas/enclosure'))} delta(s) for {version}")
