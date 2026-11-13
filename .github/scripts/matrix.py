#!/usr/bin/env python3
"""Build a GitHub Actions matrix from devices/<device>/<os>.conf.

Environment:
  TARGETS  Optional whitespace/comma separated selection. Each entry is either
           "device:os" (exact config) or "device" (every OS for that device).
           When empty, every config in devices/ is selected.

Output (stdout):
  {"include": [{"device": "sweet", "os": "lineage"}, ...]}
"""

import glob
import json
import os
import sys


def all_configs():
    entries = []
    for path in sorted(glob.glob("devices/*/*.conf")):
        entries.append(
            {
                "device": os.path.basename(os.path.dirname(path)),
                "os": os.path.splitext(os.path.basename(path))[0],
            }
        )
    return entries


def main():
    available = all_configs()
    targets = os.environ.get("TARGETS", "").strip()

    if not targets:
        selected = available
    else:
        selected = []
        seen = set()
        for token in targets.replace(",", " ").split():
            device, sep, os_name = token.partition(":")
            if sep:
                matches = [e for e in available if e["device"] == device and e["os"] == os_name]
            else:
                matches = [e for e in available if e["device"] == device]
            if not matches:
                sys.exit(f"error: '{token}' does not match any devices/<device>/<os>.conf")
            for entry in matches:
                key = (entry["device"], entry["os"])
                if key not in seen:
                    seen.add(key)
                    selected.append(entry)

    if not selected:
        sys.exit("error: no devices/<device>/<os>.conf files found")

    print(json.dumps({"include": selected}, separators=(",", ":")))


if __name__ == "__main__":
    main()
