#!/bin/bash
# JSON Formatter - 编译 & 打包脚本
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_DIR="$SCRIPT_DIR/src"
OUTPUT="$SCRIPT_DIR/JSONFormatter.alfredworkflow"

echo "🔧 JSON Formatter - 编译 & 打包"
echo "================================"
echo ""

# 检查编译器
if ! command -v swiftc &> /dev/null; then
    echo "❌ 未找到 swiftc 编译器，请安装 Xcode Command Line Tools:"
    echo "   xcode-select --install"
    exit 1
fi

# 编译
echo "📦 编译 json_formatter.swift ..."
cd "$SRC_DIR"
swiftc json_formatter.swift \
    -o json_formatter \
    -framework Cocoa \
    -framework WebKit \
    -O \
    -suppress-warnings
echo "✅ 编译成功"

# 打包
echo "📦 打包 .alfredworkflow ..."
cd "$SRC_DIR"
rm -f "$OUTPUT"
zip -r "$OUTPUT" \
    info.plist \
    json_formatter \
    json_formatter.html \
    icon.png \
    -x ".*" "*.swift"

echo ""
echo "✅ 打包完成: $OUTPUT"
echo ""
echo "📌 下一步:"
echo "   双击 JSONFormatter.alfredworkflow 导入 Alfred"
echo "   唤起 Alfred → 输入 jq → 回车"
