#!/usr/bin/env python3
"""Apply each current release delta to its real previous DMG, then verify the resulting app."""
import hashlib
import os
from pathlib import Path
import stat
import subprocess
import tempfile
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
SPARKLE = "{http://www.andymatuschak.org/xml-namespaces/sparkle}"


def run(*args):
    subprocess.run([str(x) for x in args], check=True, stdout=subprocess.DEVNULL)


def inventory(root):
    result = {}
    for path in root.rglob("*"):
        relative = str(path.relative_to(root))
        mode = stat.S_IMODE(path.lstat().st_mode)
        if path.is_symlink():
            result[relative] = ("link", os.readlink(path), mode)
        elif path.is_file():
            result[relative] = ("file", hashlib.sha256(path.read_bytes()).hexdigest(), mode)
        else:
            result[relative] = ("directory", mode)
    return result


def main():
    item = ET.parse(ROOT / "dist/appcast.xml").find("channel/item")
    expected = ROOT / "dist/Co-written.app"
    expected_files = inventory(expected)
    count = 0
    for enclosure in item.findall(SPARKLE + "deltas/enclosure"):
        old_version = enclosure.attrib[SPARKLE + "deltaFrom"]
        # The Sparkle deltaFrom value is the prior build number, not its marketing version.
        with tempfile.TemporaryDirectory(prefix="co-written-release-delta-") as work:
            base = Path(work)
            mount = base / "mounted"
            mount.mkdir()
            previous = None
            for candidate in (ROOT / "dist/updates").glob("*.dmg"):
                run("hdiutil", "attach", candidate, "-nobrowse", "-readonly", "-mountpoint", mount)
                try:
                    import plistlib
                    info = plistlib.loads((mount / "Co-written.app/Contents/Info.plist").read_bytes())
                    if info["CFBundleVersion"] == old_version:
                        previous = candidate
                        patch = ROOT / "dist/updates" / enclosure.attrib["url"].rsplit("/", 1)[-1]
                        (base / "patched").mkdir()
                        patched = base / "patched/Co-written.app"
                        run(ROOT / ".build/artifacts/sparkle/Sparkle/bin/BinaryDelta", "apply", mount / "Co-written.app", patched, patch)
                        run("codesign", "--verify", "--deep", "--strict", patched)
                        actual_files = inventory(patched)
                        if actual_files != expected_files:
                            different = sorted(k for k in set(actual_files) | set(expected_files) if actual_files.get(k) != expected_files.get(k))
                            raise RuntimeError("Patched app differs: " + ", ".join(different[:10]))
                        count += 1
                        print(f"Verified real delta from build {old_version}: contents, permissions and code signature match.")
                        break
                finally:
                    run("hdiutil", "detach", mount)
            if previous is None:
                raise RuntimeError("No prior DMG matches delta build " + old_version)
    if not count:
        print("No current release delta; Sparkle will use the full signed download.")


if __name__ == "__main__":
    main()
