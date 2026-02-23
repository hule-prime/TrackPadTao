#!/usr/bin/env bash
# Build HuyTrackMou in Release mode
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🔨 Building HuyTrackMou (release)..."
swift build -c release

BIN=".build/release/HuyTrackMou"
echo ""
echo "✅ Build thành công: $SCRIPT_DIR/$BIN"
echo ""
echo "Chạy thử:"
echo "  ./$BIN"
echo ""
echo "Hoặc cài vào /usr/local/bin:"
echo "  ./install.sh"
