#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/汇芯 Token 管家.app"
bash "$ROOT/scripts/fetch-engine.sh"
swift package --package-path "$ROOT/Bridge" resolve
python3 "$ROOT/scripts/prepare-bridge.py"
swift build --package-path "$ROOT/Bridge" -c release --product HuixinQuotaBridge
BRIDGE_BIN="$(swift build --package-path "$ROOT/Bridge" -c release --show-bin-path)"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
rm -rf "$APP/Contents/Helpers"
ditto "$ROOT/vendor/engine" "$APP/Contents/Helpers"
cp "$BRIDGE_BIN/HuixinQuotaBridge" "$APP/Contents/Helpers/"

xcrun swiftc -O -swift-version 5 -target arm64-apple-macosx14.0 "$ROOT/Sources/Quota.swift" "$ROOT/Sources/BridgeWorker.swift" "$ROOT/Sources/main.swift" -o "$APP/Contents/MacOS/HuixinQuotaManager" -framework AppKit -framework SwiftUI
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
<key>CFBundleSupportedPlatforms</key><array><string>MacOSX</string></array>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>CFBundleIdentifier</key><string>cn.huixin.quotamanager</string>
<key>CFBundleName</key><string>汇芯 Token 管家</string>
<key>CFBundleDisplayName</key><string>汇芯 Token 管家</string>
<key>CFBundleExecutable</key><string>HuixinQuotaManager</string>
<key>CFBundleShortVersionString</key><string>1.0.2</string>
<key>CFBundleVersion</key><string>5</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>LSMultipleInstancesProhibited</key><true/>
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
codesign --force --sign - "$APP/Contents/Helpers/HuixinQuotaBridge"
codesign --force --sign - "$APP"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundlePackageType' "$APP/Contents/Info.plist")" == APPL ]]
codesign --verify --strict "$APP"
printf '%s\n' '{"provider":"unsupported","connect":false}' '{"provider":"unsupported","connect":false}' | "$APP/Contents/Helpers/HuixinQuotaBridge" > "$ROOT/build/bridge-protocol-test.jsonl"
python3 - "$ROOT/build/bridge-protocol-test.jsonl" <<'PYTEST'
import sys, json
from pathlib import Path
rows = [json.loads(s) for s in Path(sys.argv[1]).read_text().splitlines()]
assert len(rows) == 2 and all(r[0].get('error') == 'Unsupported provider' for r in rows)
print('Persistent bridge JSON protocol: PASS')
PYTEST
"$APP/Contents/MacOS/HuixinQuotaManager" --engine-check
"$APP/Contents/MacOS/HuixinQuotaManager" --self-test "$ROOT/Tests/fixtures"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ROOT/build/huixin-token-manager-v1.0.2-macos-arm64.zip"
echo "$APP"
