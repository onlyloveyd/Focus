#!/bin/bash
# 打包 Focus.dmg：拖拽安装式分发镜像（universal，未签名未公证）
# 依赖：仅系统自带工具（swift / hdiutil / iconutil）
set -euo pipefail
cd "$(dirname "$0")/.."

./Scripts/make-app.sh

STAGING=".build/dmg-staging"
DMG="Focus.dmg"
rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
cp -R Focus.app "$STAGING/Focus.app"
ln -s /Applications "$STAGING/Applications"

hdiutil create -volname "Focus" -srcfolder "$STAGING" -ov -format UDZO "$DMG"

echo "✅ 已生成 $DMG"
echo "   上传到 GitHub Releases 时建议附一句：首次打开需到 系统设置 → 隐私与安全性 点「仍要打开」。"
