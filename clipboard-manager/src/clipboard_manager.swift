import Cocoa
import WebKit
import Carbon

// MARK: - Constants
let pidFile = "/tmp/clipboard_manager_\(getuid()).pid"
let dataDir = NSHomeDirectory() + "/.clipboard_manager"
let dataFile = dataDir + "/data.json"
let configFile = dataDir + "/config.json"
let maxHistoryCount = 1000

// MARK: - Data Models
struct ClipboardItem: Codable {
    var id: String
    var content: String
    var timestamp: Double
    var favorite: Bool

    init(content: String, favorite: Bool = false) {
        self.id = UUID().uuidString
        self.content = content
        self.timestamp = Date().timeIntervalSince1970
        self.favorite = favorite
    }
}

struct ClipboardData: Codable {
    var items: [ClipboardItem]

    init() {
        self.items = []
    }
}

// MARK: - Window Config
struct WindowConfig: Codable {
    var width: Double
    var height: Double
    var x: Double?
    var y: Double?

    static let defaultWidth: Double = 680
    static let defaultHeight: Double = 520

    init() {
        self.width = WindowConfig.defaultWidth
        self.height = WindowConfig.defaultHeight
        self.x = nil
        self.y = nil
    }
}

// MARK: - Config Manager
class ConfigManager {
    static let shared = ConfigManager()
    var windowConfig: WindowConfig

    private init() {
        if let data = try? Data(contentsOf: URL(fileURLWithPath: configFile)),
           let decoded = try? JSONDecoder().decode(WindowConfig.self, from: data) {
            self.windowConfig = decoded
        } else {
            self.windowConfig = WindowConfig()
        }
    }

    func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(windowConfig) {
            try? data.write(to: URL(fileURLWithPath: configFile))
        }
    }

    func saveWindowFrame(_ frame: NSRect) {
        windowConfig.width = Double(frame.size.width)
        windowConfig.height = Double(frame.size.height)
        windowConfig.x = Double(frame.origin.x)
        windowConfig.y = Double(frame.origin.y)
        save()
    }
}

// MARK: - Data Manager
class DataManager {
    static let shared = DataManager()
    var data: ClipboardData

    private init() {
        // Ensure data directory exists
        try? FileManager.default.createDirectory(atPath: dataDir, withIntermediateDirectories: true)
        // Load existing data
        if let jsonData = try? Data(contentsOf: URL(fileURLWithPath: dataFile)),
           let decoded = try? JSONDecoder().decode(ClipboardData.self, from: jsonData) {
            self.data = decoded
        } else {
            self.data = ClipboardData()
        }
    }

    func save() {
        if let jsonData = try? JSONEncoder().encode(data) {
            try? jsonData.write(to: URL(fileURLWithPath: dataFile))
        }
    }

    func addItem(_ content: String) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Deduplicate: remove existing item with same content
        data.items.removeAll { $0.content == trimmed && !$0.favorite }

        // Also update favorite items' timestamp if they match
        for i in 0..<data.items.count {
            if data.items[i].content == trimmed && data.items[i].favorite {
                data.items[i].timestamp = Date().timeIntervalSince1970
            }
        }

        // Add new item at the beginning (non-favorite)
        let item = ClipboardItem(content: trimmed)
        data.items.insert(item, at: 0)

        // Trim history (keep favorites + latest N non-favorites)
        let favorites = data.items.filter { $0.favorite }
        var nonFavorites = data.items.filter { !$0.favorite }
        if nonFavorites.count > maxHistoryCount {
            nonFavorites = Array(nonFavorites.prefix(maxHistoryCount))
        }
        data.items = nonFavorites + favorites.filter { nf in !nonFavorites.contains(where: { $0.id == nf.id }) }

        // Sort by timestamp desc
        data.items.sort { $0.timestamp > $1.timestamp }

        save()
    }

    func toggleFavorite(id: String) {
        if let idx = data.items.firstIndex(where: { $0.id == id }) {
            data.items[idx].favorite.toggle()
            save()
        }
    }

    func deleteItem(id: String) {
        data.items.removeAll { $0.id == id }
        save()
    }

    func useItem(id: String) {
        if let idx = data.items.firstIndex(where: { $0.id == id }) {
            data.items[idx].timestamp = Date().timeIntervalSince1970
            data.items.sort { $0.timestamp > $1.timestamp }
            save()
        }
    }

    func getHistoryItems() -> [ClipboardItem] {
        return data.items.filter { !$0.favorite }.sorted { $0.timestamp > $1.timestamp }
    }

    func getFavoriteItems() -> [ClipboardItem] {
        return data.items.filter { $0.favorite }.sorted { $0.timestamp > $1.timestamp }
    }

    func toJSON() -> String {
        let history = getHistoryItems()
        let favorites = getFavoriteItems()
        let dict: [String: Any] = [
            "history": history.map { itemToDict($0) },
            "favorites": favorites.map { itemToDict($0) }
        ]
        if let jsonData = try? JSONSerialization.data(withJSONObject: dict),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }
        return "{\"history\":[],\"favorites\":[]}"
    }

    private func itemToDict(_ item: ClipboardItem) -> [String: Any] {
        return [
            "id": item.id,
            "content": item.content,
            "timestamp": item.timestamp,
            "favorite": item.favorite
        ]
    }
}

// MARK: - Titlebar Drag View (manual window dragging via mouseDragged)
class TitlebarDragView: NSView {
    private var dragStart: NSPoint?

    override func mouseDown(with event: NSEvent) {
        // Record the initial mouse location in screen coordinates
        dragStart = NSEvent.mouseLocation
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = dragStart, let win = window else { return }
        let current = NSEvent.mouseLocation
        let dx = current.x - start.x
        let dy = current.y - start.y
        let origin = win.frame.origin
        win.setFrameOrigin(NSPoint(x: origin.x + dx, y: origin.y + dy))
        dragStart = current
    }

    override func mouseUp(with event: NSEvent) {
        dragStart = nil
    }

    override var mouseDownCanMoveWindow: Bool { return false }
}

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate, WKScriptMessageHandler {
    var window: NSWindow!
    var webView: WKWebView!
    var dragView: TitlebarDragView!
    private var signalSource: DispatchSourceSignal?
    private var clipboardTimer: Timer?
    private var lastChangeCount: Int = 0
    private var isWindowVisible = false
    private var previousApp: NSRunningApplication?
    private var isPasting = false  // Guard to prevent windowDidResignKey during paste
    private var isOpeningFile = false  // Guard to prevent windowDidResignKey during file open

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupMenuBar()
        writePIDFile()
        setupSignalHandler()
        createWindow()

        // Start clipboard monitoring
        lastChangeCount = NSPasteboard.general.changeCount
        startClipboardMonitoring()

        // Show window on first launch
        showWindow()
    }

    // MARK: - PID File
    func writePIDFile() {
        let pid = ProcessInfo.processInfo.processIdentifier
        try? "\(pid)".write(toFile: pidFile, atomically: true, encoding: .utf8)
    }

    func removePIDFile() {
        unlink(pidFile)
    }

    // MARK: - Signal Handler (SIGUSR1 = toggle window)
    func setupSignalHandler() {
        signal(SIGUSR1, SIG_IGN)
        let src = DispatchSource.makeSignalSource(signal: SIGUSR1, queue: .main)
        src.setEventHandler { [weak self] in
            self?.toggleWindow()
        }
        src.resume()
        signalSource = src
    }

    // MARK: - Clipboard Monitoring
    func startClipboardMonitoring() {
        clipboardTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }

    func checkClipboard() {
        let pb = NSPasteboard.general
        let currentCount = pb.changeCount
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount

        if let content = pb.string(forType: .string) {
            DataManager.shared.addItem(content)
            refreshWebView()
        }
    }

    // MARK: - Window
    func createWindow() {
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        let cfg = ConfigManager.shared.windowConfig
        let windowWidth = CGFloat(min(cfg.width, Double(screenFrame.width)))
        let windowHeight = CGFloat(min(cfg.height, Double(screenFrame.height)))

        let windowX: CGFloat
        let windowY: CGFloat
        if let savedX = cfg.x, let savedY = cfg.y {
            windowX = CGFloat(savedX)
            windowY = CGFloat(savedY)
        } else {
            windowX = screenFrame.origin.x + (screenFrame.width - windowWidth) / 2
            windowY = screenFrame.origin.y + (screenFrame.height - windowHeight) / 2
        }

        window = NSWindow(
            contentRect: NSRect(x: windowX, y: windowY, width: windowWidth, height: windowHeight),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Clipboard Manager"
        window.minSize = NSSize(width: 420, height: 320)
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = .white
        window.level = .floating
        window.delegate = self
        window.hasShadow = true

        // WKWebView configuration
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        let controller = config.userContentController
        controller.add(self, name: "pasteItem")
        controller.add(self, name: "toggleFavorite")
        controller.add(self, name: "deleteItem")
        controller.add(self, name: "hideWindow")
        controller.add(self, name: "getData")
        controller.add(self, name: "useItem")
        controller.add(self, name: "openDataFile")

        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight), configuration: config)
        webView.autoresizingMask = [.width, .height]
        webView.setValue(false, forKey: "drawsBackground")

        let htmlPath = getHTMLPath()
        if FileManager.default.fileExists(atPath: htmlPath) {
            let htmlURL = URL(fileURLWithPath: htmlPath)
            webView.loadFileURL(htmlURL, allowingReadAccessTo: htmlURL.deletingLastPathComponent())
        } else {
            webView.loadHTMLString("""
                <html><body style="font-family:-apple-system;padding:40px;text-align:center;color:#333;background:#fff;">
                <h2>⚠️ 找不到 clipboard_manager.html</h2>
                <p>请确保 clipboard_manager.html 与此程序在同一目录</p>
                <p style="color:#999;font-size:12px;">查找路径: \(htmlPath)</p>
                </body></html>
            """, baseURL: nil)
        }

        // Container view to hold WebView + drag view
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight))
        containerView.autoresizingMask = [.width, .height]
        containerView.addSubview(webView)

        // Titlebar drag view: transparent native view overlaid on top 28px
        let dragHeight: CGFloat = 28
        dragView = TitlebarDragView(frame: NSRect(x: 0, y: windowHeight - dragHeight, width: windowWidth, height: dragHeight))
        dragView.autoresizingMask = [.width, .minYMargin]
        containerView.addSubview(dragView)

        window.contentView = containerView
    }

    func showWindow() {
        // Remember which app was active before showing our window
        previousApp = NSWorkspace.shared.frontmostApplication

        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        isWindowVisible = true
        refreshWebView()
        // Focus search input
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.webView.evaluateJavaScript("focusSearch()", completionHandler: nil)
        }
    }

    func hideWindow() {
        guard isWindowVisible else { return }
        window.orderOut(nil)
        isWindowVisible = false
    }

    func toggleWindow() {
        if isWindowVisible {
            hideWindow()
        } else {
            showWindow()
        }
    }

    func refreshWebView() {
        let jsonStr = DataManager.shared.toJSON()
        let escaped = jsonStr.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
        webView.evaluateJavaScript("refreshData('\(escaped)')", completionHandler: nil)
    }

    // MARK: - Paste to Previous App
    func pasteContent(_ content: String) {
        // Set pasteboard
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(content, forType: .string)
        lastChangeCount = pb.changeCount // Prevent re-capturing our own paste

        // Set pasting guard
        isPasting = true

        // Hide window
        hideWindow()

        // Activate the previous app, then simulate Cmd+V
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [self] in
            if let prevApp = previousApp {
                prevApp.activate(options: [.activateIgnoringOtherApps])
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [self] in
                simulatePaste()
                isPasting = false
            }
        }
    }

    func simulatePaste() {
        // Simulate Cmd+V using CGEvent
        let source = CGEventSource(stateID: .hidSystemState)

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) // 0x09 = V
        keyDown?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        keyUp?.flags = .maskCommand
        keyUp?.post(tap: .cghidEventTap)
    }

    // MARK: - WKScriptMessageHandler
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        switch message.name {
        case "pasteItem":
            if let dict = message.body as? [String: Any],
               let id = dict["id"] as? String,
               let content = dict["content"] as? String {
                DataManager.shared.useItem(id: id)
                pasteContent(content)
            }

        case "toggleFavorite":
            if let id = message.body as? String {
                DataManager.shared.toggleFavorite(id: id)
                refreshWebView()
            }

        case "deleteItem":
            if let id = message.body as? String {
                DataManager.shared.deleteItem(id: id)
                refreshWebView()
            }

        case "hideWindow":
            hideWindow()

        case "getData":
            refreshWebView()

        case "useItem":
            if let dict = message.body as? [String: Any],
               let id = dict["id"] as? String,
               let content = dict["content"] as? String {
                DataManager.shared.useItem(id: id)
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setString(content, forType: .string)
                lastChangeCount = pb.changeCount
                refreshWebView()
            }

        case "openDataFile":
            isOpeningFile = true
            let fileURL = URL(fileURLWithPath: dataFile)
            if FileManager.default.fileExists(atPath: dataFile) {
                NSWorkspace.shared.open(fileURL)
            } else {
                // Open the directory if file doesn't exist yet
                let dirURL = URL(fileURLWithPath: dataDir)
                NSWorkspace.shared.open(dirURL)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.isOpeningFile = false
            }

        default:
            break
        }
    }

    // MARK: - Menu Bar
    func setupMenuBar() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "关于 Clipboard Manager", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "隐藏", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthersItem = NSMenuItem(title: "隐藏其他", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthersItem.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthersItem)
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "编辑")
        editMenu.addItem(withTitle: "撤销", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "重做", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "复制", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        NSApp.mainMenu = mainMenu
    }

    func getHTMLPath() -> String {
        let executablePath = CommandLine.arguments[0]
        let executableDir = (executablePath as NSString).deletingLastPathComponent
        return (executableDir as NSString).appendingPathComponent("clipboard_manager.html")
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false // Keep running in background
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardTimer?.invalidate()
        removePIDFile()
    }
}

// MARK: - NSWindowDelegate
extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        isWindowVisible = false
    }

    func windowDidResignKey(_ notification: Notification) {
        // Hide window when losing focus, but not during paste or file open operation
        if isWindowVisible && !isPasting && !isOpeningFile {
            hideWindow()
        }
    }

    func windowDidResize(_ notification: Notification) {
        ConfigManager.shared.saveWindowFrame(window.frame)
    }

    func windowDidMove(_ notification: Notification) {
        ConfigManager.shared.saveWindowFrame(window.frame)
    }
}

// MARK: - Entry Point
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
