#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
found=$(grep -rnE '(^|[[:space:]])//' App Sources Tests --include='*.swift' | grep -vE '//[[:space:]]*(Arrange|Act|Assert)[[:space:]]*$' || true)
if [[ -n "$found" ]]; then
  echo "$found"
  echo "Comments aren't allowed, except Arrange, Act and Assert markers in tests."
  exit 1
fi
