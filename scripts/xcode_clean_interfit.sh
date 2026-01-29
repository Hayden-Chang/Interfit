#!/usr/bin/env bash
set -euo pipefail

echo "[Interfit] Cleaning Xcode DerivedData for this project..."
echo "Tip: Quit Xcode before running this script."

DERIVED_DATA_DIR="${HOME}/Library/Developer/Xcode/DerivedData"

if [[ -d "${DERIVED_DATA_DIR}" ]]; then
  rm -rf "${DERIVED_DATA_DIR}/Interfit-"*
fi

echo "[Interfit] Re-resolving packages + verifying Shared builds (generic iOS)..."
xcodebuild -project "Interfit.xcodeproj" -scheme "Shared" -configuration Debug -destination "generic/platform=iOS" build

echo "[Interfit] Done."
