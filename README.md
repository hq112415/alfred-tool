# Alfred Workflows

一组实用的 [Alfred](https://www.alfredapp.com/) Workflow 插件集合，使用 Swift + WKWebView 构建原生 macOS 体验。

## 📦 插件列表

| 插件 | 触发方式 | 说明 |
|------|----------|------|
| [Clipboard Manager](./clipboard-manager) | `⌘⌥V` | 剪切板历史管理，支持搜索、收藏、快速粘贴 |
| [JSON Formatter](./json-formatter) | Alfred 输入 `jq` | JSON 格式化 / 压缩 / 语法高亮 / 错误检测 |

## 🛠 环境要求

- macOS 12.0+
- [Alfred 5](https://www.alfredapp.com/) + Powerpack
- Xcode Command Line Tools（用于编译 Swift 源码）

```bash
xcode-select --install
```

## 🚀 快速安装

每个插件目录下都有 `install.sh` 安装脚本，会自动编译并打包：

```bash
# 安装 Clipboard Manager
cd clipboard-manager && bash install.sh

# 安装 JSON Formatter
cd json-formatter && bash install.sh
```

安装完成后双击生成的 `.alfredworkflow` 文件即可导入 Alfred。

## 📁 项目结构

```
alfred-workflows/
├── README.md
├── LICENSE
├── .gitignore
├── clipboard-manager/
│   ├── README.md          # 插件说明
│   ├── install.sh         # 编译 & 打包脚本
│   └── src/
│       ├── info.plist             # Alfred Workflow 配置
│       ├── clipboard_manager.swift   # Swift 源码
│       └── clipboard_manager.html    # 界面
└── json-formatter/
    ├── README.md          # 插件说明
    ├── install.sh         # 编译 & 打包脚本
    └── src/
        ├── info.plist             # Alfred Workflow 配置
        ├── json_formatter.swift   # Swift 源码
        ├── json_formatter.html    # 界面
        └── icon.png               # 图标
```

## 🏗 技术栈

- **Swift** — 原生 macOS 应用，无需 Xcode 工程，单文件编译
- **WKWebView** — HTML/CSS/JS 渲染界面，灵活美观
- **CGEvent** — 模拟键盘事件实现粘贴等操作
- **SIGUSR1** — 进程间信号通信，实现 Alfred 触发窗口切换

## 📄 License

[MIT](./LICENSE)
