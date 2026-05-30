#!/bin/bash
set -e

PROJECT_DIR="/Users/zhaojing/Downloads/callflyer_Harmony"
SDK_HOME="/Applications/DevEco-Studio.app/Contents/sdk"
HARMONY_SDK="/Users/zhaojing/Library/OpenHarmony/Sdk/18/toolchains"

export DEVECO_SDK_HOME="$SDK_HOME"
export PATH="$HARMONY_SDK:$PATH"

echo "=== 1. 清理旧构建 ==="
cd "$PROJECT_DIR"
rm -rf entry/build

echo "=== 2. 构建应用 ==="
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw assembleApp

HAP_PATH="$PROJECT_DIR/entry/build/default/outputs/default/entry-default-signed.hap"
if [ ! -f "$HAP_PATH" ]; then
  echo "❌ 构建失败: $HAP_PATH 不存在"
  exit 1
fi

echo "=== 3. 安装应用 ==="
"$HARMONY_SDK/hdc" install -r "$HAP_PATH"

echo "=== 4. 启动应用 ==="
"$HARMONY_SDK/hdc" shell "aa start -a EntryAbility -b com.callflyer.app"

echo "✅ 完成"