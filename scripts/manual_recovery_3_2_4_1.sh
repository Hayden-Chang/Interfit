#!/usr/bin/env bash
set -euo pipefail

DEVICE_ID="${DEVICE_ID:-A83F34CF-F641-4F04-A959-7F9AB5AA829E}"
APP_BUNDLE_ID="${APP_BUNDLE_ID:--23.Interfit}"
APP_PATH="${APP_PATH:-/Users/pc/Library/Developer/Xcode/DerivedData/Interfit-bvarbzgohfcpfadlgftxzfwjqhgj/Build/Products/Debug-iphonesimulator/Interfit.app}"

echo "[3.2.4.1] Boot + install + seed recoverable snapshot"
xcrun simctl bootstatus "$DEVICE_ID" -b
xcrun simctl uninstall "$DEVICE_ID" "$APP_BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl install "$DEVICE_ID" "$APP_PATH"

echo "[3.2.4.1] Launching with -debugSeedRecoverableSnapshot_3_2_4_1"
xcrun simctl launch "$DEVICE_ID" "$APP_BUNDLE_ID" -debugSeedRecoverableSnapshot_3_2_4_1

echo
echo "Now perform the manual checks in the UI:"
echo "  A) Continue: should enter training in paused state, then Resume continues."
echo "  B) End & Save: should create an ended session in History and clear the prompt."
echo "  C) Discard: should clear the prompt without writing History."
echo
echo "Tip: the seed report should exist at:"
echo "  <App Container>/Library/Application Support/debug_seed_recoverable_snapshot_3_2_4_1.json"

