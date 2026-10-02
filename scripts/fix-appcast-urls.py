#!/usr/bin/env python3
"""Keep each item's assets under its own GitHub release tag, preserving CDATA notes."""
from pathlib import Path
import re
import sys
from urllib.parse import urlsplit
from xml.dom import minidom


def normalize(path, repo):
    if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", repo):
        raise ValueError("Invalid release repository")
    document = minidom.parse(str(path))
    for item in document.getElementsByTagName("item"):
        versions = item.getElementsByTagNameNS("http://www.andymatuschak.org/xml-namespaces/sparkle", "shortVersionString")
        if len(versions) != 1 or not versions[0].firstChild:
            raise ValueError("Missing marketing version")
        version = versions[0].firstChild.data
        if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", version):
            raise ValueError("Invalid marketing version")
        for enclosure in item.getElementsByTagName("enclosure"):
            filename = urlsplit(enclosure.getAttribute("url")).path.rsplit("/", 1)[-1]
            if not filename or not re.fullmatch(r"[A-Za-z0-9_.-]+", filename):
                raise ValueError("Invalid release asset filename")
            enclosure.setAttribute("url", f"https://github.com/{repo}/releases/download/v{version}/{filename}")
    serialized = document.toxml(encoding="utf-8").replace(b"?>", b"?>\n", 1)
    Path(path).write_bytes(serialized.rstrip() + b"\n")


if __name__ == "__main__":
    normalize(sys.argv[1], sys.argv[2])
