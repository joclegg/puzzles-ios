#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

DEVICE_NAME="${E2E_DEVICE:-iPhone 17}"
PART=""
TAGS=()
FLOWS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --fast) TAGS=(--include-tags=fast); shift ;;
    --part) PART="$2"; shift 2 ;;
    *) FLOWS+=("$1"); shift ;;
  esac
done

if [[ ${#FLOWS[@]} -eq 0 ]]; then
  ALL=($(ls e2e/flows/*.yaml | sort))
  if [[ -n "$PART" ]]; then
    INDEX="${PART%/*}"
    TOTAL="${PART#*/}"
    for i in "${!ALL[@]}"; do
      if [[ $((i % TOTAL)) -eq $((INDEX - 1)) ]]; then
        FLOWS+=("${ALL[$i]}")
      fi
    done
  else
    FLOWS=(e2e/flows)
  fi
fi

if [[ ${#FLOWS[@]} -eq 0 ]]; then
  echo "No flows in this part"
  exit 0
fi

if [[ -d /opt/homebrew/opt/openjdk@21 ]]; then
  export JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home}"
  export PATH="$JAVA_HOME/bin:$PATH"
fi

UDID=$(xcrun simctl list devices available | grep -F "$DEVICE_NAME (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
if [[ -z "$UDID" ]]; then
  echo "No simulator named $DEVICE_NAME"
  exit 1
fi
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null

xcodebuild -project Puzzles.xcodeproj -scheme PuzzlesApp \
  -destination "platform=iOS Simulator,id=$UDID" -derivedDataPath build build -quiet
xcrun simctl install "$UDID" build/Build/Products/Debug-iphonesimulator/Puzzles.app

maestro --device "$UDID" test ${TAGS[@]+"${TAGS[@]}"} "${FLOWS[@]}"
