#!/usr/bin/env bash
# Cài HuyTrackMou vào /usr/local/bin và tạo LaunchAgent để tự chạy khi login
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BINARY="$SCRIPT_DIR/.build/release/HuyTrackMou"
INSTALL_PATH="/usr/local/bin/HuyTrackMou"
PLIST_DIR="$HOME/Library/LaunchAgents"
PLIST_PATH="$PLIST_DIR/com.w3leee.HuyTrackMou.plist"

# Build trước nếu chưa có binary
if [ ! -f "$BINARY" ]; then
    echo "⚙️  Chưa build, đang build..."
    cd "$SCRIPT_DIR"
    swift build -c release
fi

# Copy binary
echo "📦 Cài vào $INSTALL_PATH..."
sudo cp "$BINARY" "$INSTALL_PATH"
sudo chmod +x "$INSTALL_PATH"

# Tạo LaunchAgent (tự chạy khi user login)
mkdir -p "$PLIST_DIR"
cat > "$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.w3leee.HuyTrackMou</string>
    <key>ProgramArguments</key>
    <array>
        <string>$INSTALL_PATH</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$HOME/Library/Logs/HuyTrackMou.log</string>
    <key>StandardErrorPath</key>
    <string>$HOME/Library/Logs/HuyTrackMou.log</string>
</dict>
</plist>
EOF

# Load LaunchAgent ngay
launchctl unload "$PLIST_PATH" 2>/dev/null || true
launchctl load "$PLIST_PATH"

echo ""
echo "✅ HuyTrackMou đã được cài và đang chạy!"
echo ""
echo "📋 Log: tail -f ~/Library/Logs/HuyTrackMou.log"
echo "🛑 Dừng: launchctl unload $PLIST_PATH"
echo "🔄 Khởi động lại: launchctl unload $PLIST_PATH && launchctl load $PLIST_PATH"
echo ""
echo "⚠️  Quan trọng: Cấp quyền Accessibility cho /usr/local/bin/HuyTrackMou"
echo "   System Settings → Privacy & Security → Accessibility → (+) thêm binary"
