#!/bin/bash
# 构建并打包成 Focus.app（LSUIElement：无 Dock 图标，仅菜单栏）
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

APP="Focus.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# 生成应用图标（Finder / 登录项里显示的那个）
ICONSET=".build/AppIcon.iconset"
rm -rf "$ICONSET"
swift Scripts/generate-icon.swift "$ICONSET"
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

cp .build/release/Focus "$APP/Contents/MacOS/Focus"

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
