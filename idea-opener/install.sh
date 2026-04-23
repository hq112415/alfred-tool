#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_DIR="$SCRIPT_DIR/src"
DIST_DIR="$SCRIPT_DIR/dist"
WORKFLOW_NAME="IdeaOpener"

# 查找已安装的 workflow 目录
ALFRED_WORKFLOWS_DIR="$HOME/Library/Application Support/Alfred/Alfred.alfredpreferences/workflows"
INSTALLED_DIR=""
if [ -d "$ALFRED_WORKFLOWS_DIR" ]; then
    INSTALLED_PLIST=$(find "$ALFRED_WORKFLOWS_DIR" -name "info.plist" -exec grep -l "$WORKFLOW_NAME" {} \; 2>/dev/null | head -1)
    if [ -n "$INSTALLED_PLIST" ]; then
        INSTALLED_DIR=$(dirname "$INSTALLED_PLIST")
    fi
fi

echo "🔧 $WORKFLOW_NAME - 打包 & 安装"
echo "===================================="

# 清理
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

# 打包 .alfredworkflow (本质是 zip)
echo "📦 打包 .alfredworkflow ..."
cd "$SRC_DIR"
zip -r "$DIST_DIR/$WORKFLOW_NAME.alfredworkflow" info.plist search.py Feedback.py open.sh icon.png -x "*.DS_Store"
echo "✅ 打包完成: $DIST_DIR/$WORKFLOW_NAME.alfredworkflow"

# 同步到已安装目录
if [ -n "$INSTALLED_DIR" ] && [ -d "$INSTALLED_DIR" ]; then
    echo ""
    echo "📲 同步到 Alfred ..."
    cp -f "$SRC_DIR/info.plist" "$INSTALLED_DIR/"
    cp -f "$SRC_DIR/search.py" "$INSTALLED_DIR/"
    cp -f "$SRC_DIR/Feedback.py" "$INSTALLED_DIR/"
    cp -f "$SRC_DIR/open.sh" "$INSTALLED_DIR/"
    cp -f "$SRC_DIR/icon.png" "$INSTALLED_DIR/"
    echo "✅ 已同步到: $INSTALLED_DIR"
    echo "   Alfred 下次触发时自动使用新版本"
else
    echo ""
    echo "📌 未检测到已安装的 workflow，请双击导入:"
    echo "   $DIST_DIR/$WORKFLOW_NAME.alfredworkflow"
fi
