#!/bin/zsh
# make_pkg.sh — Đóng gói TrackPadGiaCay thành .pkg installer
# User chỉ cần double-click .pkg → Next → Install, không cần Terminal

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="TrackPadGiaCay"
BUNDLE_ID="com.w3leee.TrackPadGiaCay"
VERSION="1.1"
PKG_NAME="${APP_NAME}-v${VERSION}.pkg"

BUILD_DIR="$SCRIPT_DIR/.pkg_build"
PAYLOAD_DIR="$BUILD_DIR/payload"
SCRIPTS_DIR="$BUILD_DIR/scripts"

echo "======================================="
echo "  $APP_NAME PKG Builder v$VERSION"
echo "======================================="
echo ""

# ── 1. Build universal binary ─────────────────────────────────────────────
echo "🔨 Building release binary..."
cd "$SCRIPT_DIR"

if swift build -c release --arch arm64 --arch x86_64 2>/dev/null; then
    BINARY_SRC="$SCRIPT_DIR/.build/apple/Products/Release/$APP_NAME"
    echo "   ✅ Universal binary (arm64 + x86_64)"
else
    swift build -c release
    BINARY_SRC="$SCRIPT_DIR/.build/release/$APP_NAME"
    echo "   ✅ Native binary ($(uname -m))"
fi

# ── 2. Tạo payload: app bundle ────────────────────────────────────────────
echo "📦 Tạo app bundle..."
rm -rf "$BUILD_DIR"
mkdir -p "$PAYLOAD_DIR/Applications/${APP_NAME}.app/Contents/MacOS"
mkdir -p "$PAYLOAD_DIR/Applications/${APP_NAME}.app/Contents/Resources"
mkdir -p "$SCRIPTS_DIR"

cp "$BINARY_SRC" "$PAYLOAD_DIR/Applications/${APP_NAME}.app/Contents/MacOS/$APP_NAME"
cp "$SCRIPT_DIR/Resources/Info.plist" "$PAYLOAD_DIR/Applications/${APP_NAME}.app/Contents/Info.plist"

# Ký ad-hoc
codesign --force --deep --sign - "$PAYLOAD_DIR/Applications/${APP_NAME}.app"
echo "   ✅ Signed ad-hoc"

# ── 3. Tạo postinstall script ─────────────────────────────────────────────
echo "📝 Tạo postinstall script..."
cat > "$SCRIPTS_DIR/postinstall" << 'POSTINSTALL'
#!/bin/zsh
APP_NAME="TrackPadGiaCay"
APP_PATH="/Applications/${APP_NAME}.app"
BUNDLE_ID="com.w3leee.TrackPadGiaCay"

# Tìm user đang đăng nhập (không phải root)
LOGGED_USER=$(stat -f "%Su" /dev/console 2>/dev/null || echo "$USER")
if [[ "$LOGGED_USER" == "root" ]] || [[ -z "$LOGGED_USER" ]]; then
    LOGGED_USER=$(ls -la /dev/console | awk '{print $3}')
fi
USER_HOME=$(eval echo "~$LOGGED_USER")
PLIST_DIR="$USER_HOME/Library/LaunchAgents"
PLIST_FILE="$PLIST_DIR/com.w3leee.TrackPadGiaCay.plist"
LAUNCH_LOG="$USER_HOME/Library/Logs/TrackPadGiaCay.log"

# Gỡ quarantine
xattr -dr com.apple.quarantine "$APP_PATH" 2>/dev/null || true

# Dừng instance cũ
launchctl asuser "$(id -u "$LOGGED_USER")" launchctl unload "$PLIST_FILE" 2>/dev/null || true
pkill -9 "$APP_NAME" 2>/dev/null || true
sleep 0.5

# Reset TCC Accessibility (binary mới cần grant lại)
tccutil reset Accessibility "$BUNDLE_ID" 2>/dev/null || true

# Tạo LaunchAgent
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
    <array><string>/Applications/TrackPadGiaCay.app/Contents/MacOS/TrackPadGiaCay</string></array>
    <key>RunAtLoad</key><true/>
    <key>KeepAlive</key><true/>
    <key>StandardOutPath</key>
    <string>${LAUNCH_LOG}</string>
    <key>StandardErrorPath</key>
    <string>${LAUNCH_LOG}</string>
</dict>
</plist>
PLIST

chown "$LOGGED_USER" "$PLIST_FILE"

# Load LaunchAgent với đúng user context
launchctl asuser "$(id -u "$LOGGED_USER")" launchctl load "$PLIST_FILE" 2>/dev/null || true
sleep 1

# Mở Accessibility Settings
sudo -u "$LOGGED_USER" open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility" 2>/dev/null || true

exit 0
POSTINSTALL

chmod +x "$SCRIPTS_DIR/postinstall"

# ── 4. Tạo welcome/readme HTML cho installer ─────────────────────────────
mkdir -p "$BUILD_DIR/resources"
cat > "$BUILD_DIR/resources/Welcome.html" << 'WELCOME'
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><style>
body { font-family: -apple-system, sans-serif; font-size: 13px; padding: 10px; }
h2 { color: #1d6ae5; }
li { margin: 6px 0; }
.warn { background: #fff8e1; border-left: 3px solid #f59e0b; padding: 8px 12px; border-radius: 4px; margin: 10px 0; }
.warn b { color: #b45309; }
</style></head>
<body>
<h2>🖱️ TrackPadGiaCay</h2>
<p>Điều khiển macOS bằng cử chỉ kéo chuột giữa:</p>
<ul>
  <li>← Kéo trái / → Kéo phải — chuyển app theo MRU</li>
  <li>↑ Kéo lên — Mission Control</li>
  <li>↓ Kéo xuống — Show Desktop</li>
</ul>
<div class="warn">
  <b>⚠️ Nếu macOS báo "Not Opened" / không xác minh được:</b><br>
  Đừng double-click — hãy <b>Right-click (hoặc Control+click)</b> vào file .pkg → chọn <b>Open</b> → nhấn <b>Open</b> trong hộp thoại.<br>
  <br>
  Hoặc: <b>System Settings → Privacy &amp; Security</b> → kéo xuống → nhấn <b>"Open Anyway"</b>.
</div>
<p><b>Sau khi cài xong:</b> Cấp quyền <b>Accessibility</b> trong System Settings khi được yêu cầu.</p>
</body>
</html>
WELCOME

cat > "$BUILD_DIR/resources/Conclusion.html" << 'CONCLUSION'
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><style>
body { font-family: -apple-system, sans-serif; font-size: 13px; padding: 10px; }
h2 { color: #2ca05a; }
li { margin: 6px 0; }
</style></head>
<body>
<h2>✅ Cài đặt hoàn tất!</h2>
<p>TrackPadGiaCay đã được cài vào <b>/Applications/</b> và sẽ tự khởi động khi login.</p>
<p><b>⚠️ Bước cuối bắt buộc:</b></p>
<ol>
  <li>Cửa sổ <b>System Settings → Accessibility</b> vừa mở</li>
  <li>Nhấn dấu <b>+</b> → chọn <b>TrackPadGiaCay</b> từ /Applications/</li>
  <li>Bật toggle cạnh TrackPadGiaCay</li>
</ol>
<p>Sau đó chuột giữa drag sẽ hoạt động ngay!</p>
</body>
</html>
CONCLUSION

# ── 5. pkgbuild (tạo component pkg) ──────────────────────────────────────
echo "🔧 pkgbuild..."
pkgbuild \
    --root "$PAYLOAD_DIR" \
    --scripts "$SCRIPTS_DIR" \
    --identifier "$BUNDLE_ID" \
    --version "$VERSION" \
    --install-location "/" \
    "$BUILD_DIR/component.pkg"

# ── 6. productbuild (wrap với Distribution — có Welcome/Conclusion screen) ─
echo "📦 productbuild..."
cat > "$BUILD_DIR/distribution.xml" << DISTXML
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2">
    <title>TrackPadGiaCay v${VERSION}</title>
    <welcome file="Welcome.html" mime-type="text/html"/>
    <conclusion file="Conclusion.html" mime-type="text/html"/>
    <options customize="never" require-scripts="true"/>
    <domains enable_currentUserHome="false" enable_localSystem="true"/>
    <pkg-ref id="${BUNDLE_ID}"/>
    <choices-outline>
        <line choice="default">
            <line choice="${BUNDLE_ID}"/>
        </line>
    </choices-outline>
    <choice id="default"/>
    <choice id="${BUNDLE_ID}" visible="false">
        <pkg-ref id="${BUNDLE_ID}"/>
    </choice>
    <pkg-ref id="${BUNDLE_ID}" version="${VERSION}" onConclusion="none">component.pkg</pkg-ref>
</installer-gui-script>
DISTXML

productbuild \
    --distribution "$BUILD_DIR/distribution.xml" \
    --resources "$BUILD_DIR/resources" \
    --package-path "$BUILD_DIR" \
    "$SCRIPT_DIR/$PKG_NAME"

# ── 7. Dọn dẹp ───────────────────────────────────────────────────────────
rm -rf "$BUILD_DIR"

SIZE=$(du -sh "$SCRIPT_DIR/$PKG_NAME" | cut -f1)
echo ""
echo "======================================="
echo "✅ DONE: $PKG_NAME ($SIZE)"
echo "======================================="
echo ""
echo "📤 Upload lên GitHub Releases:"
echo "   1. Vào https://github.com/hule-prime/TrackPadTao/releases/new"
echo "   2. Tag: v${VERSION}  |  Title: TrackPadGiaCay v${VERSION}"
echo "   3. Kéo thả $PKG_NAME vào 'Attach binaries'"
echo "   4. Publish release"
echo ""
echo "👤 User chỉ cần:"
echo "   1. Tải $PKG_NAME"
echo "   2. Double-click → Next → Install"
echo "   3. Cấp Accessibility khi System Settings mở"
echo ""
