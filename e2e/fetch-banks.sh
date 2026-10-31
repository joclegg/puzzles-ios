#!/usr/bin/env bash
set -euo pipefail

BASE=https://joclegg.github.io/puzzles-data
TARGET=/tmp/puzzles-e2e-banks

rm -rf "$TARGET"
mkdir -p "$TARGET"
curl -fsSL --retry 3 "$BASE/manifest.json" -o "$TARGET/manifest.json"
python3 -c 'import json,sys; print("\n".join(json.load(open(sys.argv[1]))["files"]))' "$TARGET/manifest.json" |
  while read -r file; do
    mkdir -p "$TARGET/$(dirname "$file")"
    curl -fsSL --retry 3 "$BASE/$file" -o "$TARGET/$file"
  done
