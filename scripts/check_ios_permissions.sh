#!/usr/bin/env bash
#
# Cookrange iOS Permission-String Preflight
#
# Fails the build if a plugin that touches an iOS-protected resource is a
# pubspec dependency but Info.plist is missing the matching usage-description
# key. BLK-02: NSPhotoLibraryUsageDescription shipped absent for months because
# nothing caught it before a physical-device run did (a crash, then an App
# Store rejection). This is the permanent guard so that class of defect can't
# recur silently.
#
# Usage: scripts/check_ios_permissions.sh [pubspec.yaml] [Info.plist]

set -euo pipefail

PUBSPEC="${1:-pubspec.yaml}"
PLIST="${2:-ios/Runner/Info.plist}"

if [[ ! -f "$PUBSPEC" ]]; then
  echo "check_ios_permissions: $PUBSPEC not found" >&2
  exit 1
fi
if [[ ! -f "$PLIST" ]]; then
  echo "check_ios_permissions: $PLIST not found" >&2
  exit 1
fi

# plugin:key1,key2 — plugin is matched as a pubspec.yaml dependency line
# (^  <name>: ), keys are required NS*UsageDescription entries in Info.plist.
CHECKS=(
  "image_picker:NSPhotoLibraryUsageDescription"
  "mobile_scanner:NSCameraUsageDescription"
  "geolocator:NSLocationWhenInUseUsageDescription"
  "speech_to_text:NSSpeechRecognitionUsageDescription,NSMicrophoneUsageDescription"
)

missing=0
for check in "${CHECKS[@]}"; do
  plugin="${check%%:*}"
  keys="${check#*:}"
  if ! grep -qE "^  ${plugin}:" "$PUBSPEC"; then
    continue
  fi
  IFS=',' read -ra key_list <<< "$keys"
  for key in "${key_list[@]}"; do
    if ! grep -q "<key>${key}</key>" "$PLIST"; then
      echo "check_ios_permissions: $PUBSPEC depends on '$plugin' but $PLIST has no <key>$key</key>" >&2
      missing=1
    fi
  done
done

if [[ "$missing" -ne 0 ]]; then
  echo "check_ios_permissions: FAILED — add the missing usage description(s) above" >&2
  exit 1
fi

echo "check_ios_permissions: OK — all plugin-implied usage descriptions present"
