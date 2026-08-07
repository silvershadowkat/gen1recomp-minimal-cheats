#!/usr/bin/env python3
"""Build and validate the exact SilverShadow runtime payload used by CI."""

from __future__ import annotations

import json
import re
import shutil
import sys
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DIST = ROOT / "dist"
EXTRACTED = DIST / "silvershadow_mods"
RUNTIME_LIST = ROOT / "runtime-files.txt"


def selected_files() -> list[tuple[Path, Path]]:
    selected: list[tuple[Path, Path]] = []
    for raw in RUNTIME_LIST.read_text(encoding="utf-8").splitlines():
        entry = raw.strip()
        if not entry or entry.startswith("#"):
            continue
        source = ROOT / entry
        if not source.exists():
            raise SystemExit(f"Missing runtime entry: {entry}")
        if source.is_dir():
            for child in sorted(path for path in source.rglob("*") if path.is_file()):
                selected.append((child, child.relative_to(ROOT)))
        else:
            selected.append((source, source.relative_to(ROOT)))
    return selected


def validate_payload(names: list[str], version: str) -> None:
    normalized = sorted(name.replace("\\", "/") for name in names)
    if "manifest.json" not in normalized or "main.lua" not in normalized:
        raise SystemExit("Payload is missing its root manifest or entry point")
    if not any(name.startswith("modules/") for name in normalized):
        raise SystemExit("Payload is missing the modules directory")
    forbidden = (".git/", ".github/", "references/", "tests/", "tools/", "dist/")
    bad = [name for name in normalized if name.startswith(forbidden)]
    if bad:
        raise SystemExit(f"Forbidden development files in payload: {bad}")
    if any(name.endswith((".zip", ".png", ".jpg", ".gif")) for name in normalized):
        raise SystemExit("Payload unexpectedly contains an archive or image asset")
    present = set(normalized)
    internal_reads: set[str] = set()
    for lua_path in ROOT.rglob("*.lua"):
        if "references" in lua_path.parts or "dist" in lua_path.parts:
            continue
        body = lua_path.read_text(encoding="utf-8")
        internal_reads.update(re.findall(r'mod:read\(["\']([^"\']+)["\']\)', body))
    missing_reads = sorted(path for path in internal_reads if path not in present)
    if missing_reads:
        raise SystemExit(f"Packaged mod:read targets are missing: {missing_reads}")
    # Local modules use mod:read; ordinary requires must resolve from the
    # declared engine_internals runtime rather than an unpackaged local file.
    local_requires = []
    for source, relative in selected_files():
        if source.suffix != ".lua":
            continue
        body = source.read_text(encoding="utf-8")
        for target in re.findall(r'require\(["\']([^"\']+)["\']\)', body):
            if not target.startswith("src."):
                local_requires.append(f"{relative}: {target}")
    if local_requires:
        raise SystemExit(f"Unresolved non-engine require targets: {local_requires}")
    manifest = json.loads((ROOT / "manifest.json").read_text(encoding="utf-8"))
    if manifest.get("version") != version or manifest.get("id") != "minimal_cheats":
        raise SystemExit("Manifest identity/version does not match the package")


def main() -> int:
    manifest = json.loads((ROOT / "manifest.json").read_text(encoding="utf-8"))
    version = manifest["version"]
    archive = DIST / f"silvershadow-mods-v{version}.zip"
    files = selected_files()
    expected = [str(relative).replace("\\", "/") for _, relative in files]

    DIST.mkdir(exist_ok=True)
    if EXTRACTED.exists():
        shutil.rmtree(EXTRACTED)
    EXTRACTED.mkdir()
    if archive.exists():
        archive.unlink()

    for source, relative in files:
        destination = EXTRACTED / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, destination)

    with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED) as bundle:
        for source, relative in files:
            bundle.write(source, str(relative).replace("\\", "/"))

    with zipfile.ZipFile(archive) as bundle:
        names = bundle.namelist()
        if names != expected:
            raise SystemExit("ZIP file list/order differs from runtime-files selection")
        if bundle.testzip() is not None:
            raise SystemExit("ZIP CRC validation failed")
        zipped_manifest = json.loads(bundle.read("manifest.json").decode("utf-8"))
        if zipped_manifest != manifest:
            raise SystemExit("ZIP manifest differs from source manifest")

    extracted = sorted(str(path.relative_to(EXTRACTED)).replace("\\", "/")
                       for path in EXTRACTED.rglob("*") if path.is_file())
    if extracted != sorted(expected):
        raise SystemExit("Extracted folder file list differs from ZIP selection")
    validate_payload(names, version)
    print(f"Built and validated {archive}")
    print(f"Built and validated {EXTRACTED}")
    print(f"Runtime files: {len(names)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
