#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/汇芯 Token 管家.app"
bash "$ROOT/scripts/fetch-engine.sh"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
ditto "$ROOT/vendor/engine" "$APP/Contents/Helpers"
xcrun swiftc -O -swift-version 5 -target arm64-apple-macosx14.0 "$ROOT/Sources/Quota.swift" "$ROOT/Sources/main.swift" -o "$APP/Contents/MacOS/HuixinQuotaManager" -framework AppKit -framework SwiftUI
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundleIdentifier</key><string>cn.huixin.quotamanager</string>
<key>CFBundleName</key><string>汇芯 Token 管家</string>
<key>CFBundleDisplayName</key><string>汇芯 Token 管家</string>
<key>CFBundleExecutable</key><string>HuixinQuotaManager</string>
<key>CFBundleShortVersionString</key><string>1.0.0</string>
<key>CFBundleVersion</key><string>3</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
mkdir -p "$APP/Contents/Resources/Licenses"
cp "$ROOT/LICENSE" "$ROOT/NOTICE" "$APP/Contents/Resources/"
cp "$ROOT/licenses/"* "$APP/Contents/Resources/Licenses/"
ICONSET="$ROOT/build/AppIcon.iconset"
mkdir -p "$ICONSET"
swift "$ROOT/scripts/icon.swift" "$ROOT/build/icon.png"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$ROOT/build/icon.png" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z "$double" "$double" "$ROOT/build/icon.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP"
codesign --verify --strict "$APP"
"$APP/Contents/MacOS/HuixinQuotaManager" --engine-check
"$APP/Contents/MacOS/HuixinQuotaManager" --self-test "$ROOT/Tests/fixtures"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ROOT/build/huixin-token-manager-v1.0.0-macos-arm64.zip"
echo "$APP"
