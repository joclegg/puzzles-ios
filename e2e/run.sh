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
  if [[ -n "$PART" || ${#TAGS[@]} -gt 0 ]]; then
    ALL=()
    for f in $(ls e2e/flows/*.yaml | sort); do
      if [[ ${#TAGS[@]} -eq 0 ]] || grep -qE '^[[:space:]]*-[[:space:]]*fast[[:space:]]*$' "$f"; then
        ALL+=("$f")
      fi
    done
  fi
  if [[ -n "$PART" ]]; then
    FLOWS=($(printf '%s\n' ${ALL[@]+"${ALL[@]}"} | e2e/partition.sh "$PART" e2e/flow-times.txt))
  elif [[ ${#TAGS[@]} -gt 0 ]]; then
    FLOWS=(${ALL[@]+"${ALL[@]}"})
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

e2e/fetch-banks.sh

APP="${E2E_APP_PATH:-}"
if [[ -z "$APP" ]]; then
  xcodebuild -project Puzzles.xcodeproj -scheme PuzzlesApp \
    -destination "platform=iOS Simulator,id=$UDID" -derivedDataPath build build -quiet
  APP=build/Build/Products/Debug-iphonesimulator/Puzzles.app
fi
xcrun simctl install "$UDID" "$APP"

maestro --device "$UDID" test ${TAGS[@]+"${TAGS[@]}"} "${FLOWS[@]}"
