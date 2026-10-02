#!/usr/bin/env python3
import plistlib
import sys
from pathlib import Path

path, version, build, feed = sys.argv[1:]
info = {
    "CFBundleName": "Co-written", "CFBundleDisplayName": "Co-written",
    "CFBundleIdentifier": "au.com.acousland.CoWritten", "CFBundleExecutable": "CoWrittenMac",
    "CFBundlePackageType": "APPL", "NSPrincipalClass": "CoWrittenApplication", "CFBundleShortVersionString": version,
    "CFBundleVersion": build, "CFBundleIconFile": "CoWritten",
    "LSMinimumSystemVersion": "14.0", "LSUIElement": True, "NSHighResolutionCapable": True,
    "NSHumanReadableCopyright": "Copyright © 2026 Aaron Cousland. MIT licence.",
    "NSAppleEventsUsageDescription": "Co-written reads only your highlighted text in Microsoft Word, including selections across pages, for writing analysis.",
    "NSServices": [{"NSMenuItem": {"default": "Analyse with Co-written"},
        "NSMessage": "analyzeSelection", "NSPortName": "Co-written",
        "NSSendTypes": ["public.utf8-plain-text", "NSStringPboardType"]}],
}
if feed != "none":
    if not feed.startswith("https://"):
        raise SystemExit("The update feed must use HTTPS")
    info.update(SUFeedURL=feed, SUPublicEDKey=Path("Assets/update-public-key").read_text().strip(),
                SUEnableAutomaticChecks=True, SUAutomaticallyUpdate=False)
Path(path).write_bytes(plistlib.dumps(info))
