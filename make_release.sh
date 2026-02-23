#!/bin/zsh
# make_release.sh — Đóng gói TrackPadGiaCay để phân phối qua GitHub Releases
#
# Output: dist/TrackPadGiaCay-v<VERSION>.zip
#   Bên trong zip:
#     TrackPadGiaCay.app/   — app bundle, ký ad-hoc
#     install.sh            — user chạy 1 lần để cài

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="TrackPadGiaCay"
VERSION="1.1"                          # ← đổi version tại đây khi release mới
ZIP_NAME="${APP_NAME}-v${VERSION}.zip"
DIST_DIR="$SCRIPT_DIR/dist"
BUILD_APP="$DIST_DIR/${APP_NAME}.app"

echo "==============================="
echo "  $APP_NAME Release Builder v$VERSION"
echo "==============================="
echo ""

# ── 1. Build universal binary (arm64 + x86_64) ───────────────────────────
echo "🔨 Building release binary..."
cd "$SCRIPT_DIR"

# Thử build universal, fallback về native nếu không hỗ trợ
if swift build -c release --arch arm64 --arch x86_64 2>/dev/null; then
    BINARY_SRC="$SCRIPT_DIR/.build/apple/Products/Release/$APP_NAME"
    echo "   ✅ Universal binary (arm64 + x86_64)"
else
    swift build -c release
    BINARY_SRC="$SCRIPT_DIR/.build/release/$APP_NAME"
    ARCH=$(uname -m)
    echo "   ✅ Native binary ($ARCH)"
fi

# ── 2. Tạo .app bundle trong dist/ ──────────────────────────────────────
echo "📦 Tạo .app bundle..."
rm -rf "$DIST_DIR"
mkdir -p "$BUILD_APP/Contents/MacOS"
mkdir -p "$BUILD_APP/Contents/Resources"

cp "$BINARY_SRC" "$BUILD_APP/Contents/MacOS/$APP_NAME"
cp "$SCRIPT_DIR/Resources/Info.plist" "$BUILD_APP/Contents/Info.plist"

# ── 3. Ký ad-hoc (không cần Developer cert — user phải xử lý Gatekeeper) ──
echo "✍️  Ký ad-hoc..."
codesign --force --deep --sign - "$BUILD_APP"

# ── 4. Tạo install.sh đi kèm ────────────────────────────────────────────
echo "📝 Tạo install.sh..."
cat > "$DIST_DIR/install.sh" << 'INSTALL_SCRIPT'
#!/bin/zsh
# install.sh — Cài TrackPadGiaCay vào máy
# Chạy: chmod +x install.sh && ./install.sh

set -e
APP_NAME="TrackPadGiaCay"
INSTALL_DIR="$HOME/Applications"
APP_DEST="$INSTALL_DIR/${APP_NAME}.app"
PLIST_DIR="$HOME/Library/LaunchAgents"
PLIST_FILE="$PLIST_DIR/com.w3leee.TrackPadGiaCay.plist"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_SRC="$SCRIPT_DIR/${APP_NAME}.app"

echo "======================================="
echo "  Cài đặt $APP_NAME"
echo "======================================="

# Kiểm tra app có trong cùng thư mục không
if [[ ! -d "$APP_SRC" ]]; then
    echo "❌ Không tìm thấy ${APP_NAME}.app trong cùng thư mục."
    echo "   Hãy giữ install.sh và TrackPadGiaCay.app ở cùng 1 folder rồi thử lại."
    exit 1
fi

# Dừng instance cũ nếu có
launchctl unload "$PLIST_FILE" 2>/dev/null || true
pkill -9 "$APP_NAME" 2>/dev/null || true
sleep 0.5

# Cài vào ~/Applications/
echo "📂 Cài vào $INSTALL_DIR ..."
mkdir -p "$INSTALL_DIR"
rm -rf "$APP_DEST"
cp -R "$APP_SRC" "$APP_DEST"

# Gỡ quarantine (bypass Gatekeeper cho app không notarized)
echo "🔓 Gỡ quarantine..."
xattr -dr com.apple.quarantine "$APP_DEST" 2>/dev/null || true
xattr -dr com.apple.quarantine "$APP_DEST/Contents/MacOS/$APP_NAME" 2>/dev/null || true

# Tạo LaunchAgent
echo "🚀 Tạo LaunchAgent (auto-start khi login)..."
mkdir -p "$PLIST_DIR"
cat > "$PLIST_FILE" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.w3leee.TrackPadGiaCay</string>
    <key>ProgramArguments</key>
    <array><string>${APP_DEST}/Contents/MacOS/${APP_NAME}</string></array>
    <key>RunAtLoad</key><true/>
    <key>KeepAlive</key><true/>
    <key>StandardOutPath</key>
    <string>${HOME}/Library/Logs/TrackPadGiaCay.log</string>
    <key>StandardErrorPath</key>
    <string>${HOME}/Library/Logs/TrackPadGiaCay.log</string>
</dict>
</plist>
PLIST

launchctl load "$PLIST_FILE"
sleep 2

PID=$(pgrep -x "$APP_NAME" || true)
if [[ -n "$PID" ]]; then
    echo ""
    echo "✅ TrackPadGiaCay đang chạy (PID=$PID)"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "⚠️  Bước cuối — Cấp quyền Accessibility:"
    echo "   1. System Settings → Privacy & Security → Accessibility"
    echo "   2. Nhấn + và chọn TrackPadGiaCay từ ~/Applications/"
    echo "      (hoặc bật toggle nếu đã có sẵn)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
else
    echo ""
    echo "⚠️  App chưa tự khởi động. Thử mở thủ công:"
    echo "   open '$APP_DEST'"
    echo ""
    echo "   Nếu macOS chặn, vào System Settings → Privacy & Security"
    echo "   → kéo xuống → 'Open Anyway'"
fi

echo ""
echo "📖 Để gỡ cài đặt:"
echo "   launchctl unload ~/Library/LaunchAgents/com.w3leee.TrackPadGiaCay.plist"
echo "   rm -rf ~/Applications/TrackPadGiaCay.app"
echo "   rm ~/Library/LaunchAgents/com.w3leee.TrackPadGiaCay.plist"
INSTALL_SCRIPT

chmod +x "$DIST_DIR/install.sh"

# ── 5. Tạo ZIP ──────────────────────────────────────────────────────────
echo "🗜  Nén thành $ZIP_NAME ..."
cd "$DIST_DIR"
zip -qry "$SCRIPT_DIR/$ZIP_NAME" "${APP_NAME}.app" "install.sh"
cd "$SCRIPT_DIR"

SIZE=$(du -sh "$ZIP_NAME" | cut -f1)
echo ""
echo "==============================="
echo "✅ DONE: $ZIP_NAME ($SIZE)"
echo "==============================="
echo ""
echo "📤 Upload lên GitHub Releases:"
echo "   1. Vào https://github.com/hule-prime/TrackPadTao/releases/new"
echo "   2. Tạo tag: v${VERSION}"
echo "   3. Kéo thả file $ZIP_NAME vào phần 'Attach binaries'"
echo "   4. Publish release"
echo ""
echo "👤 Hướng dẫn cho user:"
echo "   1. Tải $ZIP_NAME từ Releases"
echo "   2. Giải nén"
echo "   3. Mở Terminal → cd vào thư mục vừa giải nén"
echo "   4. chmod +x install.sh && ./install.sh"
echo "   5. Cấp Accessibility khi được hỏi"
echo ""

# Dọn dẹp thư mục tạm
rm -rf "$DIST_DIR"
