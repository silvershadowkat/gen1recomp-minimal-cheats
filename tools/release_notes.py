#!/usr/bin/env python3
"""Extract one SilverShadow version section from CHANGELOG.md."""

from __future__ import annotations

import re
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 3:
        raise SystemExit("usage: release_notes.py VERSION OUTPUT")
    version, output = sys.argv[1], Path(sys.argv[2])
    lines = Path("CHANGELOG.md").read_text(encoding="utf-8").splitlines()
    notes = [f"SilverShadow Mods v{version}", ""]
    capture = False
    for line in lines:
        if re.match(rf"^##\s+{re.escape(version)}\s+-\s+", line):
            capture = True
            continue
        if capture and line.startswith("## "):
            break
        if capture:
            notes.append(line)
    if len(notes) == 2:
        notes.append("Automated release.")
    output.write_text("\n".join(notes).rstrip() + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
