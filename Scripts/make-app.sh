#!/bin/bash
# 构建并打包成 Focus.app（LSUIElement：无 Dock 图标，仅菜单栏）
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release --arch arm64 --arch x86_64

APP="Focus.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# 生成应用图标（Finder / 登录项里显示的那个）
ICONSET=".build/AppIcon.iconset"
rm -rf "$ICONSET"
swift Scripts/generate-icon.swift "$ICONSET"
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

# 多架构(--arch)构建的产物位于 .build/apple/Products/Release，单架构在 .build/release
BIN=".build/release/Focus"
if [ -f ".build/apple/Products/Release/Focus" ]; then
    BIN=".build/apple/Products/Release/Focus"
fi
cp "$BIN" "$APP/Contents/MacOS/Focus"
ARCHS=$(lipo -archs "$APP/Contents/MacOS/Focus")
if [[ "$ARCHS" != *arm64* || "$ARCHS" != *x86_64* ]]; then
    echo "❌ 产物不是双架构：$ARCHS（请检查 swift build 参数）" && exit 1
fi
echo "架构: $ARCHS"

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>Focus</string>
    <key>CFBundleIdentifier</key><string>com.yidong.focus</string>
    <key>CFBundleName</key><string>Focus</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
EOF

touch "$APP"  # 让 Finder 刷新图标缓存
echo "✅ 已生成 $APP"
echo "   可拖入 /Applications，并在 系统设置 → 通用 → 登录项与扩展 → 开机时打开 中添加它。"
