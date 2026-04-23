#!/bin/bash
# Coding Tool - 编译 & 打包脚本
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_DIR="$SCRIPT_DIR/src"
OUTPUT="$SCRIPT_DIR/CodingTool.alfredworkflow"

echo "🔧 Coding Tool - 编译 & 打包"
echo "================================"
echo ""

# 检查编译器
if ! command -v swiftc &> /dev/null; then
    echo "❌ 未找到 swiftc 编译器，请安装 Xcode Command Line Tools:"
    echo "   xcode-select --install"
    exit 1
fi

# 编译
echo "📦 编译 coding_tool.swift ..."
cd "$SRC_DIR"
swiftc coding_tool.swift \
    -o coding_tool \
    -framework Cocoa \
    -O \
    -suppress-warnings
echo "✅ 编译成功"

# 打包
echo "📦 打包 .alfredworkflow ..."
cd "$SRC_DIR"
rm -f "$OUTPUT"
zip -r "$OUTPUT" \
    info.plist \
    coding_tool \
    icon.png \
    -x ".*" "*.swift" "*.html"

echo ""
echo "✅ 打包完成: $OUTPUT"

# 自动同步到 Alfred workflow 目录（如果已安装）
ALFRED_WORKFLOW_DIR="$HOME/Library/Application Support/Alfred/Alfred.alfredpreferences/workflows"
if [ -d "$ALFRED_WORKFLOW_DIR" ]; then
    INSTALLED=$(find "$ALFRED_WORKFLOW_DIR" -name "coding_tool" -type f 2>/dev/null | head -1)
    if [ -n "$INSTALLED" ]; then
        DEST_DIR=$(dirname "$INSTALLED")
        cp "$SRC_DIR/coding_tool" "$DEST_DIR/coding_tool"
        echo "🔄 已自动同步到 Alfred: $DEST_DIR"
        echo ""
        echo "📌 下次唤起 ct 即使用最新版本（如有旧进程在运行，需先关闭）"
    else
        echo ""
        echo "📌 下一步:"
        echo "   双击 CodingTool.alfredworkflow 导入 Alfred"
        echo "   唤起 Alfred → 输入 ct → 回车"
    fi
else
    echo ""
    echo "📌 下一步:"
    echo "   双击 CodingTool.alfredworkflow 导入 Alfred"
    echo "   唤起 Alfred → 输入 ct → 回车"
fi
