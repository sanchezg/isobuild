# Copyright (C) 2026 gsanz.dev
# Licensed under GNU GPL version 3 only, with the additional notice-preservation
# term in ATTRIBUTION.md. See LICENSE and ATTRIBUTION.md.

"""Bundle the corresponding project source with each compiled application."""
import argparse
from pathlib import Path
from zipfile import ZipFile, ZipInfo, ZIP_DEFLATED

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--output", required=True)
args = parser.parse_args()
output = Path(args.output)
output.parent.mkdir(parents=True, exist_ok=True)

files = [root / name for name in [
    "LICENSE", "ATTRIBUTION.md", "LICENSING.md", "README.md", "DECISIONS.md", "RELEASE_NOTES.md", "AGENTS.md",
    "Package.swift", ".gitignore",
]]
for directory in ["Sources", "Tests", "Resources", "Config", "Tools", "IsoBuild.xcodeproj"]:
    files.extend(path for path in (root / directory).rglob("*") if path.is_file()
                 and "xcuserdata" not in path.parts and "__pycache__" not in path.parts
                 and path.name != ".DS_Store")

if any(not file.is_file() for file in files):
    raise SystemExit("The corresponding source is incomplete; missing project or license files.")

with ZipFile(output, "w", compression=ZIP_DEFLATED) as archive:
    for file in sorted(set(files)):
        relative = file.relative_to(root).as_posix()
        entry = ZipInfo("IsoBuild/" + relative, date_time=(2026, 10, 14, 0, 0, 0))
        entry.compress_type = ZIP_DEFLATED
        entry.external_attr = 0o100644 << 16
        archive.writestr(entry, file.read_bytes())

print(f"Bundled {len(set(files))} corresponding source files")
