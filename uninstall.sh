#!/usr/bin/env bash
# Gỡ cài đặt HuyTrackMou
set -e

INSTALL_PATH="/usr/local/bin/HuyTrackMou"
PLIST_PATH="$HOME/Library/LaunchAgents/com.w3leee.HuyTrackMou.plist"

echo "🗑️  Gỡ HuyTrackMou..."

launchctl unload "$PLIST_PATH" 2>/dev/null && echo "  ✓ Dừng LaunchAgent" || true
[ -f "$PLIST_PATH" ]     && rm "$PLIST_PATH"     && echo "  ✓ Xoá plist" || true
[ -f "$INSTALL_PATH" ]   && sudo rm "$INSTALL_PATH" && echo "  ✓ Xoá binary" || true

echo "✅ Đã gỡ xong."
