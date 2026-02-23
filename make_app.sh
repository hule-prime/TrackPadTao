#!/bin/zsh
# make_app.sh — Build TrackPadGiaCay và đóng gói thành .app bundle
# Usage: ./make_app.sh

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="TrackPadGiaCay"
CERT_NAME="${APP_NAME} Dev"
APP_BUNDLE="$HOME/Desktop/${APP_NAME}.app"
BINARY_SRC="$SCRIPT_DIR/.build/release/$APP_NAME"
PLIST_AGENT="$HOME/Library/LaunchAgents/com.w3leee.TrackPadGiaCay.plist"

# ── Tạo self-signed cert một lần duy nhất ────────────────────────────────
# Dùng cert cố định → TCC không bị revoke sau mỗi lần rebuild
if ! security find-identity -v -p codesigning 2>/dev/null | grep -q "$CERT_NAME"; then
    echo "🔑 Tạo self-signed code signing cert '$CERT_NAME' (chỉ làm 1 lần)..."
    TMP=$(mktemp -d)
    cat > "$TMP/req.cnf" << 'EOF'
[req]
distinguished_name = dn
x509_extensions    = ext
prompt             = no

[dn]
CN = TrackPadGiaCay Dev

[ext]
keyUsage           = critical, digitalSignature
extendedKeyUsage   = critical, codeSigning
subjectKeyIdentifier = hash
EOF
    openssl genrsa -out "$TMP/key.pem" 2048 2>/dev/null
    openssl req -new -x509 -key "$TMP/key.pem" -out "$TMP/cert.pem" \
        -days 3650 -config "$TMP/req.cnf" 2>/dev/null

    # Import cert + key vào login keychain
    security import "$TMP/cert.pem" -k ~/Library/Keychains/login.keychain-db \
        -T /usr/bin/codesign 2>/dev/null || true
    security import "$TMP/key.pem" -k ~/Library/Keychains/login.keychain-db \
        -T /usr/bin/codesign 2>/dev/null || true

    # Trust cert cho code signing (macOS sẽ hỏi password keychain 1 lần)
    echo "   macOS sẽ hỏi mật khẩu keychain để trust cert — nhập vào rồi OK..."
    security add-trusted-cert -d -r trustRoot \
        -k ~/Library/Keychains/login.keychain-db "$TMP/cert.pem" 2>/dev/null || true

    rm -rf "$TMP"
    echo "✅ Cert đã tạo và trust xong."
    echo ""
fi

# ── Build ────────────────────────────────────────────────────────────────
echo "🔨 Building $APP_NAME..."
cd "$SCRIPT_DIR"
swift build -c release

echo "📦 Cập nhật .app bundle tại $APP_BUNDLE ..."

# Unload LaunchAgent + kill trước khi thay binary
launchctl unload "$PLIST_AGENT" 2>/dev/null || true
pkill -9 "$APP_NAME" 2>/dev/null || true
sleep 0.5

# Tạo structure nếu chưa có (lần đầu) — KHÔNG xóa bundle để TCC giữ permission
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Chỉ copy binary + plist, không rm -rf bundle
cp "$BINARY_SRC" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "$SCRIPT_DIR/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

echo "✍️  Signing với '$CERT_NAME'..."
# Thử ký với cert ổn định trước, fallback sang ad-hoc
if security find-identity -v -p codesigning 2>/dev/null | grep -q "$CERT_NAME"; then
    codesign --force --deep --sign "$CERT_NAME" "$APP_BUNDLE" 2>/dev/null \
        || codesign --force --deep --sign - "$APP_BUNDLE"
else
    codesign --force --deep --sign - "$APP_BUNDLE"
fi

echo "🚀 Cài LaunchAgent (auto-start khi login)..."
cat > "$PLIST_AGENT" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.w3leee.TrackPadGiaCay</string>
    <key>ProgramArguments</key>
    <array><string>${APP_BUNDLE}/Contents/MacOS/${APP_NAME}</string></array>
    <key>RunAtLoad</key><true/>
    <key>KeepAlive</key><true/>
    <key>StandardOutPath</key>
    <string>${HOME}/Library/Logs/TrackPadGiaCay.log</string>
    <key>StandardErrorPath</key>
    <string>${HOME}/Library/Logs/TrackPadGiaCay.log</string>
</dict>
</plist>
EOF

# Reset TCC Accessibility (CDHash thay đổi sau mỗi build — cần grant lại)
# KHÔNG reset AppleEvents để Automation permission persist qua các lần rebuild
tccutil reset Accessibility com.w3leee.TrackPadGiaCay 2>/dev/null || true

launchctl load "$PLIST_AGENT"
sleep 2

PID=$(pgrep -x "$APP_NAME" || true)
if [[ -n "$PID" ]]; then
    echo "✅ $APP_NAME đang chạy (PID=$PID)"
    echo ""
    echo "⚠️  Cần cấp lại Accessibility (do binary mới — TCC đã được reset):"
    echo "   System Settings → Privacy & Security → Accessibility"
    echo "   → Bật toggle cạnh TrackPadGiaCay (hoặc + nếu chưa có)"
    open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
else
    echo "⚠️  App chưa khởi động được — kiểm tra log:"
    echo "   tail -f ~/Library/Logs/TrackPadGiaCay.log"
fi
