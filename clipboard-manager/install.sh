#!/bin/bash
# Clipboard Manager - 编译 & 打包脚本
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_DIR="$SCRIPT_DIR/src"
OUTPUT="$SCRIPT_DIR/ClipboardManager.alfredworkflow"

echo "🔧 Clipboard Manager - 编译 & 打包"
echo "===================================="
echo ""

# 检查编译器
if ! command -v swiftc &> /dev/null; then
    echo "❌ 未找到 swiftc 编译器，请安装 Xcode Command Line Tools:"
    echo "   xcode-select --install"
    exit 1
fi

# 编译
echo "📦 编译 clipboard_manager.swift ..."
cd "$SRC_DIR"
swiftc clipboard_manager.swift \
    -o clipboard_manager \
    -framework Cocoa \
    -framework WebKit \
    -framework Carbon \
    -O \
    -suppress-warnings
echo "✅ 编译成功"

# 创建数据目录
echo "📁 创建数据目录 ~/.clipboard_manager ..."
mkdir -p ~/.clipboard_manager

# 打包
echo "📦 打包 .alfredworkflow ..."
cd "$SRC_DIR"
rm -f "$OUTPUT"
zip -r "$OUTPUT" \
    info.plist \
    clipboard_manager \
    clipboard_manager.html \
    -x ".*" "*.swift"

echo ""
echo "✅ 打包完成: $OUTPUT"
echo ""
echo "📌 下一步:"
echo "   双击 ClipboardManager.alfredworkflow 导入 Alfred"
echo "   使用 ⌘⌥V 呼出剪切板管理面板"
echo ""
echo "⚠️  首次使用请确保:"
echo "   系统设置 → 隐私与安全性 → 辅助功能 → 添加 Alfred 权限"
