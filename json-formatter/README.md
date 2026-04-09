# JSON Formatter

一个强大的 JSON 格式化 Alfred 插件，支持语法高亮和错误检测。

## ✨ 功能特性

- **左右面板布局** — 左侧输入 JSON，右侧展示格式化结果
- **智能格式化** — 标准 JSON 格式化，支持自定义缩进
- **语法高亮** — 键、字符串、数字、布尔值、null 各有颜色区分
- **错误检测** — JSON 无效时尽力格式化，并红色高亮标出错误位置
- **压缩 / Minify** — 一键将 JSON 压缩为单行
- **复制结果** — 快速复制格式化后的 JSON
- **拖拽导入** — 支持将 `.json` 文件拖拽到输入区域
- **粘贴自动格式化** — 粘贴 JSON 后自动格式化
- **可调分隔栏** — 左右面板宽度可拖拽调整

## 📦 安装

```bash
bash install.sh
```

安装后双击生成的 `JSONFormatter.alfredworkflow` 导入 Alfred。

## 🚀 使用方法

1. 唤起 Alfred（默认 `⌘ + Space`）
2. 输入 `jq`
3. 回车，即可打开 JSON 格式化面板

### 界面操作

| 功能 | 操作 |
|------|------|
| 格式化 | 点击「▶ 格式化」按钮 |
| 压缩 | 点击顶部「📦 压缩」按钮 |
| 复制 | 点击顶部「📄 复制」按钮 |
| 清空 | 点击顶部「🗑 清空」按钮 |
| 示例 | 点击顶部「📋 示例」加载示例 JSON |

### ⌨️ 快捷键

| 快捷键 | 功能 |
|--------|------|
| `⌘ + Enter` | 格式化 JSON |
| `⌘ + Shift + M` | 压缩 JSON |
| `⌘ + Shift + C` | 复制格式化结果 |

## 📁 文件结构

```
json-formatter/
├── README.md
├── install.sh                # 编译 & 打包脚本
└── src/
    ├── info.plist            # Alfred Workflow 配置
    ├── json_formatter.swift  # Swift 源码
    ├── json_formatter.html   # 界面 HTML
    └── icon.png              # 图标
```

## 🔴 错误处理

输入无效 JSON 时，工具会：
1. 尽力格式化可识别的部分
2. 红色高亮标记错误位置所在行
3. 顶部显示错误信息和位置（行号、列号）
4. 行号栏中错误行以红色显示

## 🛠 技术说明

- Swift 原生应用，WKWebView 渲染界面
- 纯前端 JSON 解析和格式化，无外部依赖
- 错误处理采用「尽力格式化」策略
- Catppuccin Mocha 主题配色方案
