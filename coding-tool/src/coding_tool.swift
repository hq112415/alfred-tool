import Cocoa

// MARK: - Constants
let pidFile = "/tmp/coding_tool_\(getuid()).pid"

// MARK: - Theme
struct T {
    static let bg = NSColor(calibratedRed: 0.969, green: 0.973, blue: 0.98, alpha: 1)
    static let bgCard = NSColor.white
    static let bgInput = NSColor(calibratedRed: 0.98, green: 0.984, blue: 0.988, alpha: 1)
    static let bgHover = NSColor(calibratedRed: 0.933, green: 0.941, blue: 0.957, alpha: 1)
    static let t1 = NSColor(calibratedRed: 0.114, green: 0.141, blue: 0.2, alpha: 1)
    static let t2 = NSColor(calibratedRed: 0.353, green: 0.376, blue: 0.439, alpha: 1)
    static let t3 = NSColor(calibratedRed: 0.612, green: 0.639, blue: 0.69, alpha: 1)
    static let accent = NSColor(calibratedRed: 0.231, green: 0.51, blue: 0.965, alpha: 1)
    static let accentH = NSColor(calibratedRed: 0.145, green: 0.388, blue: 0.922, alpha: 1)
    static let green = NSColor(calibratedRed: 0.086, green: 0.639, blue: 0.29, alpha: 1)
    static let red = NSColor(calibratedRed: 0.863, green: 0.149, blue: 0.149, alpha: 1)
    static let yellow = NSColor(calibratedRed: 0.792, green: 0.541, blue: 0.016, alpha: 1)
    static let peach = NSColor(calibratedRed: 0.918, green: 0.345, blue: 0.047, alpha: 1)
    static let purple = NSColor(calibratedRed: 0.576, green: 0.2, blue: 0.918, alpha: 1)
    static let brd = NSColor(calibratedRed: 0.886, green: 0.898, blue: 0.918, alpha: 1)
    static let brdL = NSColor(calibratedRed: 0.933, green: 0.941, blue: 0.957, alpha: 1)
    static let jKey = NSColor(calibratedRed: 0.145, green: 0.388, blue: 0.922, alpha: 1)
    static let jStr = NSColor(calibratedRed: 0.086, green: 0.639, blue: 0.29, alpha: 1)
    static let jNum = NSColor(calibratedRed: 0.918, green: 0.345, blue: 0.047, alpha: 1)
    static let jBool = NSColor(calibratedRed: 0.576, green: 0.2, blue: 0.918, alpha: 1)
    static let jNull = NSColor(calibratedRed: 0.863, green: 0.149, blue: 0.149, alpha: 1)
    static let jBrk = NSColor(calibratedRed: 0.392, green: 0.455, blue: 0.545, alpha: 1)
    static let mono = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
    static let monoSm = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
}

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var mainVC: MainVC!
    private var sigSrc: DispatchSourceSignal?
    private var lockFD: Int32 = -1

    func applicationDidFinishLaunching(_ n: Notification) {
        // 单例检查：使用文件锁确保只有一个实例
        let lockFile = "/tmp/coding_tool_\(getuid()).lock"
        lockFD = open(lockFile, O_CREAT | O_WRONLY, 0o600)
        if lockFD >= 0 {
            if flock(lockFD, LOCK_EX | LOCK_NB) != 0 {
                // 另一个实例已经在运行，发送 SIGUSR1 唤醒它然后退出
                if let pidStr = try? String(contentsOfFile: pidFile, encoding: .utf8),
                   let pid = Int32(pidStr.trimmingCharacters(in: .whitespacesAndNewlines)) {
                    kill(pid, SIGUSR1)
                }
                NSApp.terminate(nil)
                return
            }
        }
        NSApp.setActivationPolicy(.regular)
        setupMenuBar()
        writePID()
        setupSignal()
        createWindow()
    }
    func writePID() { try? "\(ProcessInfo.processInfo.processIdentifier)".write(toFile: pidFile, atomically: true, encoding: .utf8) }
    func removePID() { unlink(pidFile) }
    func setupSignal() {
        signal(SIGUSR1, SIG_IGN)
        let s = DispatchSource.makeSignalSource(signal: SIGUSR1, queue: .main)
        s.setEventHandler { [weak self] in self?.bringFront() }
        s.resume(); sigSrc = s
    }
    func createWindow() {
        let scr = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        let w = min(1100, scr.width * 0.75), h = min(700, scr.height * 0.8)
        let x = scr.origin.x + (scr.width - w) / 2, y = scr.origin.y + (scr.height - h) / 2
        window = NSWindow(contentRect: NSRect(x: x, y: y, width: w, height: h),
                          styleMask: [.titled, .closable, .resizable, .miniaturizable],
                          backing: .buffered, defer: false)
        window.title = "Coding Tool"
        window.minSize = NSSize(width: 600, height: 400)
        window.isReleasedWhenClosed = false
        mainVC = MainVC()
        window.contentViewController = mainVC
        bringFront()
    }
    func bringFront() {
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }
    func setupMenuBar() {
        let m = NSMenu()
        let a1 = NSMenuItem(); let am = NSMenu()
        am.addItem(withTitle: "关于 Coding Tool", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        am.addItem(.separator())
        am.addItem(withTitle: "隐藏 Coding Tool", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let ho = NSMenuItem(title: "隐藏其他", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        ho.keyEquivalentModifierMask = [.command, .option]; am.addItem(ho)
        am.addItem(withTitle: "显示全部", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        am.addItem(.separator())
        am.addItem(withTitle: "退出 Coding Tool", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        a1.submenu = am; m.addItem(a1)

        let a2 = NSMenuItem(); let em = NSMenu(title: "编辑")
        em.addItem(withTitle: "撤销", action: Selector(("undo:")), keyEquivalent: "z")
        em.addItem(withTitle: "重做", action: Selector(("redo:")), keyEquivalent: "Z")
        em.addItem(.separator())
        em.addItem(withTitle: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        em.addItem(withTitle: "复制", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        em.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        em.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        a2.submenu = em; m.addItem(a2)

        let a3 = NSMenuItem(); let wm = NSMenu(title: "窗口")
        wm.addItem(withTitle: "最小化", action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m")
        wm.addItem(withTitle: "关闭", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        a3.submenu = wm; m.addItem(a3)
        NSApp.mainMenu = m
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ s: NSApplication) -> Bool { true }
    func applicationWillTerminate(_ n: Notification) {
        removePID()
        if lockFD >= 0 { flock(lockFD, LOCK_UN); close(lockFD) }
        unlink("/tmp/coding_tool_\(getuid()).lock")
    }
}

// MARK: - Main View Controller
class MainVC: NSViewController {
    var currentTab = 0
    let tabBar = NSView()
    var tabBtns: [NSButton] = []
    let indicator = NSView()
    let container = NSView()
    var jsonPage: NSView!
    var tsPage: NSView!
    var jsonVC: JSONVC!
    var tsVC: TimestampVC!
    var indicatorLead: NSLayoutConstraint?
    var indicatorW: NSLayoutConstraint?
    var eventMonitor: Any?

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 1100, height: 700))
        view.wantsLayer = true
        view.layer?.backgroundColor = T.bg.cgColor
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        jsonVC = JSONVC()
        tsVC = TimestampVC()
        setupKeyMonitor()
        jsonPage = jsonVC.view
        tsPage = tsVC.view

        // Tab bar
        tabBar.wantsLayer = true
        tabBar.layer?.backgroundColor = T.bgCard.cgColor
        tabBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tabBar)

        let bLine = NSView()
        bLine.wantsLayer = true; bLine.layer?.backgroundColor = T.brd.cgColor
        bLine.translatesAutoresizingMaskIntoConstraints = false; tabBar.addSubview(bLine)

        let logoBox = NSView()
        logoBox.wantsLayer = true; logoBox.layer?.backgroundColor = T.accent.cgColor
        logoBox.layer?.cornerRadius = 6; logoBox.translatesAutoresizingMaskIntoConstraints = false
        tabBar.addSubview(logoBox)

        let logoL = NSTextField(labelWithString: "CT")
        logoL.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .bold)
        logoL.textColor = .white; logoL.translatesAutoresizingMaskIntoConstraints = false
        logoBox.addSubview(logoL)

        let titleL = NSTextField(labelWithString: "Coding Tool")
        titleL.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        titleL.textColor = T.t1; titleL.translatesAutoresizingMaskIntoConstraints = false
        tabBar.addSubview(titleL)

        let titles = ["{ } JSON 格式化", "🕐 时间戳转换"]
        var lastA: NSLayoutXAxisAnchor = titleL.trailingAnchor
        for (i, t) in titles.enumerated() {
            let b = NSButton(title: t, target: self, action: #selector(tabClick(_:)))
            b.tag = i; b.isBordered = false
            b.font = NSFont.systemFont(ofSize: 13, weight: .medium)
            b.contentTintColor = T.t3; b.translatesAutoresizingMaskIntoConstraints = false
            tabBar.addSubview(b); tabBtns.append(b)
            NSLayoutConstraint.activate([
                b.leadingAnchor.constraint(equalTo: lastA, constant: i == 0 ? 20 : 4),
                b.centerYAnchor.constraint(equalTo: tabBar.centerYAnchor),
                b.heightAnchor.constraint(equalTo: tabBar.heightAnchor),
            ])
            lastA = b.trailingAnchor
        }

        indicator.wantsLayer = true; indicator.layer?.backgroundColor = T.accent.cgColor
        indicator.translatesAutoresizingMaskIntoConstraints = false; tabBar.addSubview(indicator)

        // Container
        container.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(container)
        jsonPage.translatesAutoresizingMaskIntoConstraints = false; tsPage.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(jsonPage); container.addSubview(tsPage)

        NSLayoutConstraint.activate([
            tabBar.topAnchor.constraint(equalTo: view.topAnchor),
            tabBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tabBar.heightAnchor.constraint(equalToConstant: 44),

            bLine.leadingAnchor.constraint(equalTo: tabBar.leadingAnchor),
            bLine.trailingAnchor.constraint(equalTo: tabBar.trailingAnchor),
            bLine.bottomAnchor.constraint(equalTo: tabBar.bottomAnchor),
            bLine.heightAnchor.constraint(equalToConstant: 1),

            logoBox.leadingAnchor.constraint(equalTo: tabBar.leadingAnchor, constant: 16),
            logoBox.centerYAnchor.constraint(equalTo: tabBar.centerYAnchor),
            logoBox.widthAnchor.constraint(equalToConstant: 26),
            logoBox.heightAnchor.constraint(equalToConstant: 26),

            logoL.centerXAnchor.constraint(equalTo: logoBox.centerXAnchor),
            logoL.centerYAnchor.constraint(equalTo: logoBox.centerYAnchor),

            titleL.leadingAnchor.constraint(equalTo: logoBox.trailingAnchor, constant: 8),
            titleL.centerYAnchor.constraint(equalTo: tabBar.centerYAnchor),

            indicator.bottomAnchor.constraint(equalTo: tabBar.bottomAnchor),
            indicator.heightAnchor.constraint(equalToConstant: 2),

            container.topAnchor.constraint(equalTo: tabBar.bottomAnchor),
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            container.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            jsonPage.topAnchor.constraint(equalTo: container.topAnchor),
            jsonPage.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            jsonPage.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            jsonPage.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            tsPage.topAnchor.constraint(equalTo: container.topAnchor),
            tsPage.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            tsPage.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            tsPage.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        switchTab(0)
    }

    func switchTab(_ i: Int) {
        currentTab = i
        jsonPage.isHidden = i != 0
        tsPage.isHidden = i != 1
        for (j, b) in tabBtns.enumerated() {
            b.contentTintColor = j == i ? T.accent : T.t3
            b.font = NSFont.systemFont(ofSize: 13, weight: j == i ? .semibold : .medium)
        }
        indicatorLead?.isActive = false; indicatorW?.isActive = false
        let btn = tabBtns[i]
        indicatorLead = indicator.leadingAnchor.constraint(equalTo: btn.leadingAnchor)
        indicatorW = indicator.widthAnchor.constraint(equalTo: btn.widthAnchor)
        indicatorLead?.isActive = true; indicatorW?.isActive = true
        if i == 0 { view.window?.makeFirstResponder(jsonVC.inputTV) }
        else { view.window?.makeFirstResponder(tsVC.toDateRows.first?.input) }
    }

    @objc func tabClick(_ s: NSButton) { switchTab(s.tag) }

    func setupKeyMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

            // ESC: 先关搜索栏，再退出程序
            if event.keyCode == 53 {
                if self.currentTab == 0 && !self.jsonVC.searchBar.isHidden {
                    self.jsonVC.closeSearch()
                    return nil
                }
                NSApp.terminate(nil); return nil
            }

            // Tab (无修饰键): 切换标签
            if event.keyCode == 48 && !flags.contains(.command) && !flags.contains(.option) && !flags.contains(.control) {
                // 如果搜索框有焦点，不拦截 Tab
                if let fr = self.view.window?.firstResponder as? NSText,
                   fr == self.jsonVC.searchField.currentEditor() { return event }
                self.switchTab(self.currentTab == 0 ? 1 : 0)
                return nil
            }

            // Cmd+F: 打开搜索（仅在 JSON 页）
            if flags.contains(.command) && event.charactersIgnoringModifiers?.lowercased() == "f" && self.currentTab == 0 {
                self.jsonVC.openSearch()
                return nil
            }

            // Cmd+Enter: 格式化（仅在 JSON 页）
            if flags.contains(.command) && event.keyCode == 36 && self.currentTab == 0 {
                self.jsonVC.formatJSON()
                return nil
            }

            // Cmd+Shift+M: 压缩
            if flags.contains(.command) && flags.contains(.shift) && event.charactersIgnoringModifiers?.lowercased() == "m" && self.currentTab == 0 {
                self.jsonVC.minifyJSON()
                return nil
            }

            // Cmd+Shift+C: 复制输出
            if flags.contains(.command) && flags.contains(.shift) && event.charactersIgnoringModifiers?.lowercased() == "c" && self.currentTab == 0 {
                self.jsonVC.copyOutput()
                return nil
            }

            return event
        }
    }

    deinit {
        if let monitor = eventMonitor { NSEvent.removeMonitor(monitor) }
    }
}

// MARK: - JSON Formatter
class JSONVC: NSViewController, NSTextViewDelegate {
    var inputTV: CustomTextView!
    var inputScroll: NSScrollView!
    var outputTV: CustomTextView!
    var outputScroll: NSScrollView!
    var gutterTV: NSTextView!
    var gutterScroll: NSScrollView!
    let headerV = NSView()
    let searchBar = NSView()
    var searchField: NSTextField!
    var searchInfoL: NSTextField!
    let statusV = NSView()
    let statusDot = NSView()
    let statusL = NSTextField(labelWithString: "等待输入")
    let inputSizeL = NSTextField(labelWithString: "0 chars")
    let outputSizeL = NSTextField(labelWithString: "0 lines")
    let errorBanner = NSView()
    let errorL = NSTextField(labelWithString: "")
    let leftPanel = NSView()
    let rightPanel = NSView()
    let dividerV = NSView()
    var leftW: NSLayoutConstraint!
    var dividerDragging = false
    var lastFormatted = ""
    var lastParsed: Any? = nil
    var isValid = false
    var indentSize = 2
    var searchMatches: [NSRange] = []
    var inputSearchMatches: [NSRange] = []
    var searchIdx = -1
    /// true = current match is in output, false = in input
    var searchInOutput = true
    var lastSearchQuery = ""
    var searchHighlightColor = NSColor(calibratedRed: 0.996, green: 0.941, blue: 0.424, alpha: 1)
    var searchCurrentColor = NSColor(calibratedRed: 0.984, green: 0.573, blue: 0.235, alpha: 1)
    var formatDebounceTimer: Timer?
    /// Foldable region: stores line ranges that can be collapsed
    struct FoldRegion {
        let startLine: Int   // line index (0-based) where { or [ is
        let endLine: Int     // line index (0-based) where matching } or ] is
        var collapsed: Bool  // whether this region is currently collapsed
    }
    var foldRegions: [FoldRegion] = []
    /// The full formatted lines (before folding)
    var fullFormattedLines: [String] = []

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 1100, height: 650))
        view.wantsLayer = true; view.layer?.backgroundColor = T.bg.cgColor
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    func setupUI() {
        // ---- Header ----
        headerV.wantsLayer = true; headerV.layer?.backgroundColor = T.bgCard.cgColor
        headerV.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(headerV)

        let hLine = NSView(); hLine.wantsLayer = true; hLine.layer?.backgroundColor = T.brd.cgColor
        hLine.translatesAutoresizingMaskIntoConstraints = false; headerV.addSubview(hLine)

        let btns: [(String, Selector)] = [
            ("✨ 格式化", #selector(formatJSON)),
            ("📦 删除空格", #selector(minifyJSON)),
            ("🔒 删除空格并转义", #selector(minifyAndEscape)),
            ("🔓 去除转义", #selector(unescapeJSON)),
        ]
        let rightBtns: [(String, Selector)] = [
            ("📋 示例", #selector(loadSample)),
            ("🗑 清空", #selector(clearAll)),
            ("📄 复制", #selector(copyOutput)),
        ]

        var lastA: NSLayoutXAxisAnchor = headerV.leadingAnchor
        for (i, s) in btns.enumerated() {
            let b = makeBtn(s.0, action: s.1); headerV.addSubview(b)
            NSLayoutConstraint.activate([
                b.leadingAnchor.constraint(equalTo: lastA, constant: i == 0 ? 14 : 6),
                b.centerYAnchor.constraint(equalTo: headerV.centerYAnchor),
            ])
            lastA = b.trailingAnchor
        }
        var rA: NSLayoutXAxisAnchor = headerV.trailingAnchor
        for s in rightBtns.reversed() {
            let b = makeBtn(s.0, action: s.1); headerV.addSubview(b)
            NSLayoutConstraint.activate([
                b.trailingAnchor.constraint(equalTo: rA, constant: -6),
                b.centerYAnchor.constraint(equalTo: headerV.centerYAnchor),
            ])
            rA = b.leadingAnchor
        }

        // ---- Search Bar ----
        searchBar.wantsLayer = true; searchBar.layer?.backgroundColor = T.bgCard.cgColor
        searchBar.translatesAutoresizingMaskIntoConstraints = false; searchBar.isHidden = true

        let sLine = NSView(); sLine.wantsLayer = true; sLine.layer?.backgroundColor = T.brd.cgColor
        sLine.translatesAutoresizingMaskIntoConstraints = false; searchBar.addSubview(sLine)

        let sIcon = NSTextField(labelWithString: "🔍"); sIcon.font = NSFont.systemFont(ofSize: 13)
        sIcon.translatesAutoresizingMaskIntoConstraints = false; searchBar.addSubview(sIcon)

        searchField = NSTextField(); searchField.placeholderString = "搜索..."
        searchField.font = T.mono; searchField.focusRingType = .none
        searchField.isBordered = false; searchField.drawsBackground = true
        searchField.backgroundColor = NSColor.white
        searchField.wantsLayer = true; searchField.layer?.cornerRadius = 6
        searchField.layer?.borderWidth = 1; searchField.layer?.borderColor = T.brd.cgColor
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.target = self; searchField.action = #selector(performSearch)
        searchBar.addSubview(searchField)

        searchInfoL = NSTextField(labelWithString: ""); searchInfoL.font = NSFont.systemFont(ofSize: 12)
        searchInfoL.textColor = T.t3; searchInfoL.alignment = .center
        searchInfoL.translatesAutoresizingMaskIntoConstraints = false; searchBar.addSubview(searchInfoL)

        let prevBtn = NSButton(title: "▲", target: self, action: #selector(searchPrev))
        prevBtn.bezelStyle = .roundRect; prevBtn.font = NSFont.systemFont(ofSize: 12)
        prevBtn.translatesAutoresizingMaskIntoConstraints = false; searchBar.addSubview(prevBtn)

        let nextBtn = NSButton(title: "▼", target: self, action: #selector(searchNext))
        nextBtn.bezelStyle = .roundRect; nextBtn.font = NSFont.systemFont(ofSize: 12)
        nextBtn.translatesAutoresizingMaskIntoConstraints = false; searchBar.addSubview(nextBtn)

        let copyVB = NSButton(title: "📋 复制值", target: self, action: #selector(copyMatchedValues))
        copyVB.bezelStyle = .roundRect; copyVB.font = NSFont.systemFont(ofSize: 11); copyVB.tag = 1
        copyVB.translatesAutoresizingMaskIntoConstraints = false; searchBar.addSubview(copyVB)

        let copyPB = NSButton(title: "📋 复制键值", target: self, action: #selector(copyMatchedPairs))
        copyPB.bezelStyle = .roundRect; copyPB.font = NSFont.systemFont(ofSize: 11); copyPB.tag = 2
        copyPB.translatesAutoresizingMaskIntoConstraints = false; searchBar.addSubview(copyPB)

        let closeSB = NSButton(title: "✕", target: self, action: #selector(closeSearch))
        closeSB.bezelStyle = .roundRect; closeSB.font = NSFont.systemFont(ofSize: 12)
        closeSB.translatesAutoresizingMaskIntoConstraints = false; searchBar.addSubview(closeSB)

        // ---- Error Banner ----
        errorBanner.wantsLayer = true
        errorBanner.layer?.backgroundColor = NSColor(calibratedRed: 0.996, green: 0.949, blue: 0.949, alpha: 1).cgColor
        errorBanner.translatesAutoresizingMaskIntoConstraints = false; errorBanner.isHidden = true

        let eIcon = NSTextField(labelWithString: "⚠️"); eIcon.font = NSFont.systemFont(ofSize: 14)
        eIcon.translatesAutoresizingMaskIntoConstraints = false; errorBanner.addSubview(eIcon)
        errorL.font = NSFont.systemFont(ofSize: 12); errorL.textColor = T.red
        errorL.lineBreakMode = .byTruncatingTail; errorL.translatesAutoresizingMaskIntoConstraints = false
        errorBanner.addSubview(errorL)

        // ---- Main Area (left panel + divider + right panel) ----
        let mainArea = NSView()
        mainArea.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(mainArea)
        // Add searchBar & errorBanner AFTER mainArea so they are on top (higher z-order)
        view.addSubview(searchBar); view.addSubview(errorBanner)

        leftPanel.wantsLayer = true; leftPanel.layer?.backgroundColor = T.bgCard.cgColor
        leftPanel.layer?.cornerRadius = 10; leftPanel.layer?.borderWidth = 1
        leftPanel.layer?.borderColor = T.brd.cgColor; leftPanel.translatesAutoresizingMaskIntoConstraints = false
        mainArea.addSubview(leftPanel)

        // Left panel header
        let lHeader = NSView(); lHeader.wantsLayer = true; lHeader.layer?.backgroundColor = T.bg.cgColor
        lHeader.translatesAutoresizingMaskIntoConstraints = false; leftPanel.addSubview(lHeader)
        let lHLine = NSView(); lHLine.wantsLayer = true; lHLine.layer?.backgroundColor = T.brdL.cgColor
        lHLine.translatesAutoresizingMaskIntoConstraints = false; lHeader.addSubview(lHLine)
        let lDot = NSView(); lDot.wantsLayer = true; lDot.layer?.cornerRadius = 3
        lDot.layer?.backgroundColor = T.accent.cgColor; lDot.translatesAutoresizingMaskIntoConstraints = false; lHeader.addSubview(lDot)
        let lTitle = NSTextField(labelWithString: "输入"); lTitle.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        lTitle.textColor = T.t3; lTitle.translatesAutoresizingMaskIntoConstraints = false; lHeader.addSubview(lTitle)
        inputSizeL.font = NSFont.systemFont(ofSize: 10); inputSizeL.textColor = T.t3
        inputSizeL.wantsLayer = true; inputSizeL.layer?.cornerRadius = 8
        inputSizeL.layer?.backgroundColor = T.bgCard.cgColor; inputSizeL.layer?.borderWidth = 1
        inputSizeL.layer?.borderColor = T.brdL.cgColor; inputSizeL.alignment = .center
        inputSizeL.translatesAutoresizingMaskIntoConstraints = false; lHeader.addSubview(inputSizeL)

        // Input text view
        inputScroll = NSScrollView(); inputScroll.hasVerticalScroller = true
        inputScroll.borderType = .noBorder; inputScroll.drawsBackground = true
        inputScroll.backgroundColor = T.bgInput; inputScroll.translatesAutoresizingMaskIntoConstraints = false
        inputTV = CustomTextView(); inputTV.isEditable = true; inputTV.isSelectable = true
        inputTV.isRichText = false; inputTV.font = T.mono; inputTV.textColor = T.t1
        inputTV.backgroundColor = T.bgInput; inputTV.textContainerInset = NSSize(width: 14, height: 14)
        inputTV.isAutomaticQuoteSubstitutionEnabled = false; inputTV.isAutomaticDashSubstitutionEnabled = false
        inputTV.isAutomaticTextReplacementEnabled = false; inputTV.delegate = self; inputTV.allowsUndo = true
        inputTV.minSize = NSSize(width: 0, height: 0)
        inputTV.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        inputTV.isVerticallyResizable = true; inputTV.isHorizontallyResizable = false
        inputTV.autoresizingMask = [.width]
        inputTV.textContainer?.widthTracksTextView = true
        inputTV.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        inputTV.onKeyEquivalent = { [weak self] event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if flags.contains(.command) && event.charactersIgnoringModifiers?.lowercased() == "f" {
                self?.openSearch(); return true
            }
            if flags.contains(.command) && event.keyCode == 36 {
                self?.formatJSON(); return true
            }
            return false
        }
        inputScroll.documentView = inputTV; leftPanel.addSubview(inputScroll)

        // Action bar
        let actionBar = NSView(); actionBar.wantsLayer = true; actionBar.layer?.backgroundColor = T.bg.cgColor
        actionBar.translatesAutoresizingMaskIntoConstraints = false; leftPanel.addSubview(actionBar)
        let aLine = NSView(); aLine.wantsLayer = true; aLine.layer?.backgroundColor = T.brdL.cgColor
        aLine.translatesAutoresizingMaskIntoConstraints = false; actionBar.addSubview(aLine)

        let fmtBtn = NSButton(title: "▶ 格式化", target: self, action: #selector(formatJSON))
        fmtBtn.wantsLayer = true; fmtBtn.layer?.backgroundColor = T.accent.cgColor
        fmtBtn.layer?.cornerRadius = 7; fmtBtn.contentTintColor = .white
        fmtBtn.isBordered = false; fmtBtn.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        fmtBtn.translatesAutoresizingMaskIntoConstraints = false; actionBar.addSubview(fmtBtn)

        let indentSel = NSPopUpButton(); indentSel.addItem(withTitle: "2 空格")
        indentSel.addItem(withTitle: "4 空格"); indentSel.addItem(withTitle: "Tab")
        indentSel.selectItem(at: 0); indentSel.font = NSFont.systemFont(ofSize: 12)
        indentSel.translatesAutoresizingMaskIntoConstraints = false; indentSel.target = self
        indentSel.target = self; indentSel.action = #selector(indentChanged); actionBar.addSubview(indentSel)

        let shortcutL = NSTextField(labelWithString: "⌘+Enter 格式化  ⌘F 搜索  ESC 关闭")
        shortcutL.font = NSFont.systemFont(ofSize: 11); shortcutL.textColor = T.t3
        shortcutL.translatesAutoresizingMaskIntoConstraints = false; actionBar.addSubview(shortcutL)

        // Divider
        dividerV.wantsLayer = true; dividerV.layer?.backgroundColor = NSColor.clear.cgColor
        dividerV.translatesAutoresizingMaskIntoConstraints = false; mainArea.addSubview(dividerV)
        let divLine = NSView(); divLine.wantsLayer = true; divLine.layer?.cornerRadius = 2
        divLine.layer?.backgroundColor = NSColor(calibratedRed: 0.796, green: 0.835, blue: 0.882, alpha: 1).cgColor
        divLine.translatesAutoresizingMaskIntoConstraints = false; dividerV.addSubview(divLine)

        // Right panel
        rightPanel.wantsLayer = true; rightPanel.layer?.backgroundColor = T.bgCard.cgColor
        rightPanel.layer?.cornerRadius = 10; rightPanel.layer?.borderWidth = 1
        rightPanel.layer?.borderColor = T.brd.cgColor; rightPanel.translatesAutoresizingMaskIntoConstraints = false
        mainArea.addSubview(rightPanel)

        let rHeader = NSView(); rHeader.wantsLayer = true; rHeader.layer?.backgroundColor = T.bg.cgColor
        rHeader.translatesAutoresizingMaskIntoConstraints = false; rightPanel.addSubview(rHeader)
        let rHLine = NSView(); rHLine.wantsLayer = true; rHLine.layer?.backgroundColor = T.brdL.cgColor
        rHLine.translatesAutoresizingMaskIntoConstraints = false; rHeader.addSubview(rHLine)
        let rDot = NSView(); rDot.wantsLayer = true; rDot.layer?.cornerRadius = 3
        rDot.layer?.backgroundColor = T.green.cgColor; rDot.translatesAutoresizingMaskIntoConstraints = false; rHeader.addSubview(rDot)
        let rTitle = NSTextField(labelWithString: "输出"); rTitle.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        rTitle.textColor = T.t3; rTitle.translatesAutoresizingMaskIntoConstraints = false; rHeader.addSubview(rTitle)

        let expandBtn = NSButton(title: "⊞", target: self, action: #selector(expandAll))
        expandBtn.bezelStyle = .roundRect; expandBtn.font = NSFont.systemFont(ofSize: 12)
        expandBtn.translatesAutoresizingMaskIntoConstraints = false; rHeader.addSubview(expandBtn)
        let collapseBtn = NSButton(title: "⊟", target: self, action: #selector(collapseAll))
        collapseBtn.bezelStyle = .roundRect; collapseBtn.font = NSFont.systemFont(ofSize: 12)
        collapseBtn.translatesAutoresizingMaskIntoConstraints = false; rHeader.addSubview(collapseBtn)

        outputSizeL.font = NSFont.systemFont(ofSize: 10); outputSizeL.textColor = T.t3
        outputSizeL.wantsLayer = true; outputSizeL.layer?.cornerRadius = 8
        outputSizeL.layer?.backgroundColor = T.bgCard.cgColor; outputSizeL.layer?.borderWidth = 1
        outputSizeL.layer?.borderColor = T.brdL.cgColor; outputSizeL.alignment = .center
        outputSizeL.translatesAutoresizingMaskIntoConstraints = false; rHeader.addSubview(outputSizeL)

        // Output: gutter + text
        let outWrapper = NSView(); outWrapper.translatesAutoresizingMaskIntoConstraints = false; rightPanel.addSubview(outWrapper)

        gutterScroll = NSScrollView(); gutterScroll.hasVerticalScroller = false
        gutterScroll.borderType = .noBorder; gutterScroll.drawsBackground = true
        gutterScroll.backgroundColor = T.bg; gutterScroll.translatesAutoresizingMaskIntoConstraints = false
        gutterTV = NSTextView(); gutterTV.isEditable = false; gutterTV.isSelectable = false
        gutterTV.isRichText = true; gutterTV.font = T.monoSm; gutterTV.textColor = T.t3
        gutterTV.backgroundColor = T.bg; gutterTV.textContainerInset = NSSize(width: 8, height: 14)
        gutterTV.isAutomaticQuoteSubstitutionEnabled = false
        gutterTV.minSize = NSSize(width: 0, height: 0)
        gutterTV.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        gutterTV.isVerticallyResizable = true; gutterTV.isHorizontallyResizable = false
        gutterTV.autoresizingMask = [.width]
        gutterTV.textContainer?.widthTracksTextView = true
        gutterTV.textContainer?.containerSize = NSSize(width: 56, height: CGFloat.greatestFiniteMagnitude)
        gutterScroll.documentView = gutterTV; outWrapper.addSubview(gutterScroll)

        outputScroll = NSScrollView(); outputScroll.hasVerticalScroller = true
        outputScroll.borderType = .noBorder; outputScroll.drawsBackground = true
        outputScroll.backgroundColor = T.bgInput; outputScroll.translatesAutoresizingMaskIntoConstraints = false
        outputTV = CustomTextView(); outputTV.isEditable = false; outputTV.isSelectable = true
        outputTV.isRichText = true; outputTV.font = T.mono; outputTV.textColor = T.t1
        outputTV.backgroundColor = T.bgInput; outputTV.textContainerInset = NSSize(width: 14, height: 14)
        outputTV.minSize = NSSize(width: 0, height: 0)
        outputTV.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        outputTV.isVerticallyResizable = true; outputTV.isHorizontallyResizable = false
        outputTV.autoresizingMask = [.width]
        outputTV.textContainer?.widthTracksTextView = true
        outputTV.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        outputTV.onKeyEquivalent = { [weak self] event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if flags.contains(.command) && event.charactersIgnoringModifiers?.lowercased() == "f" {
                self?.openSearch(); return true
            }
            return false
        }
        outputScroll.documentView = outputTV; outWrapper.addSubview(outputScroll)

        // Sync gutter scroll with output
        outputScroll.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(self, selector: #selector(outputScrolled), name: NSView.boundsDidChangeNotification, object: outputScroll.contentView)

        // Gutter click for fold/unfold
        let gutterClick = NSClickGestureRecognizer(target: self, action: #selector(gutterClicked(_:)))
        gutterTV.addGestureRecognizer(gutterClick)

        // ---- Status Bar ----
        statusV.wantsLayer = true; statusV.layer?.backgroundColor = T.bgCard.cgColor
        statusV.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(statusV)
        let sLine2 = NSView(); sLine2.wantsLayer = true; sLine2.layer?.backgroundColor = T.brd.cgColor
        sLine2.translatesAutoresizingMaskIntoConstraints = false; statusV.addSubview(sLine2)
        statusDot.wantsLayer = true; statusDot.layer?.cornerRadius = 3
        statusDot.layer?.backgroundColor = T.t3.cgColor; statusDot.translatesAutoresizingMaskIntoConstraints = false
        statusV.addSubview(statusDot)
        statusL.font = NSFont.systemFont(ofSize: 11); statusL.textColor = T.t3
        statusL.translatesAutoresizingMaskIntoConstraints = false; statusV.addSubview(statusL)
        let hintL = NSTextField(labelWithString: "Tab 切换  ⌘F 搜索  ESC 关闭")
        hintL.font = NSFont.systemFont(ofSize: 11); hintL.textColor = T.t3
        hintL.translatesAutoresizingMaskIntoConstraints = false; statusV.addSubview(hintL)

        // ---- Layout ----
        leftW = leftPanel.widthAnchor.constraint(equalTo: mainArea.widthAnchor, multiplier: 0.5)

        NSLayoutConstraint.activate([
            // Header
            headerV.topAnchor.constraint(equalTo: view.topAnchor),
            headerV.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerV.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerV.heightAnchor.constraint(equalToConstant: 40),
            hLine.leadingAnchor.constraint(equalTo: headerV.leadingAnchor),
            hLine.trailingAnchor.constraint(equalTo: headerV.trailingAnchor),
            hLine.bottomAnchor.constraint(equalTo: headerV.bottomAnchor),
            hLine.heightAnchor.constraint(equalToConstant: 1),

            // Search bar (overlaid on top of mainArea when visible)
            searchBar.topAnchor.constraint(equalTo: headerV.bottomAnchor),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            searchBar.heightAnchor.constraint(equalToConstant: 36),
            sLine.leadingAnchor.constraint(equalTo: searchBar.leadingAnchor),
            sLine.trailingAnchor.constraint(equalTo: searchBar.trailingAnchor),
            sLine.bottomAnchor.constraint(equalTo: searchBar.bottomAnchor),
            sLine.heightAnchor.constraint(equalToConstant: 1),
            sIcon.leadingAnchor.constraint(equalTo: searchBar.leadingAnchor, constant: 14),
            sIcon.centerYAnchor.constraint(equalTo: searchBar.centerYAnchor),
            searchField.leadingAnchor.constraint(equalTo: sIcon.trailingAnchor, constant: 8),
            searchField.centerYAnchor.constraint(equalTo: searchBar.centerYAnchor),
            searchField.widthAnchor.constraint(equalToConstant: 200),
            searchField.heightAnchor.constraint(equalToConstant: 24),
            searchInfoL.leadingAnchor.constraint(equalTo: searchField.trailingAnchor, constant: 8),
            searchInfoL.centerYAnchor.constraint(equalTo: searchBar.centerYAnchor),
            searchInfoL.widthAnchor.constraint(equalToConstant: 80),
            prevBtn.leadingAnchor.constraint(equalTo: searchInfoL.trailingAnchor, constant: 4),
            prevBtn.centerYAnchor.constraint(equalTo: searchBar.centerYAnchor),
            nextBtn.leadingAnchor.constraint(equalTo: prevBtn.trailingAnchor, constant: 2),
            nextBtn.centerYAnchor.constraint(equalTo: searchBar.centerYAnchor),
            copyVB.leadingAnchor.constraint(equalTo: nextBtn.trailingAnchor, constant: 8),
            copyVB.centerYAnchor.constraint(equalTo: searchBar.centerYAnchor),
            copyPB.leadingAnchor.constraint(equalTo: copyVB.trailingAnchor, constant: 4),
            copyPB.centerYAnchor.constraint(equalTo: searchBar.centerYAnchor),
            closeSB.trailingAnchor.constraint(equalTo: searchBar.trailingAnchor, constant: -14),
            closeSB.centerYAnchor.constraint(equalTo: searchBar.centerYAnchor),

            // Error banner (overlaid below header when visible)
            errorBanner.topAnchor.constraint(equalTo: headerV.bottomAnchor),
            errorBanner.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            errorBanner.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            errorBanner.heightAnchor.constraint(equalToConstant: 32),
            eIcon.leadingAnchor.constraint(equalTo: errorBanner.leadingAnchor, constant: 14),
            eIcon.centerYAnchor.constraint(equalTo: errorBanner.centerYAnchor),
            errorL.leadingAnchor.constraint(equalTo: eIcon.trailingAnchor, constant: 8),
            errorL.trailingAnchor.constraint(equalTo: errorBanner.trailingAnchor, constant: -14),
            errorL.centerYAnchor.constraint(equalTo: errorBanner.centerYAnchor),

            // Main area (directly below header, not dependent on hidden views)
            mainArea.topAnchor.constraint(equalTo: headerV.bottomAnchor),
            mainArea.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            mainArea.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            mainArea.bottomAnchor.constraint(equalTo: statusV.topAnchor),

            leftPanel.topAnchor.constraint(equalTo: mainArea.topAnchor),
            leftPanel.leadingAnchor.constraint(equalTo: mainArea.leadingAnchor),
            leftPanel.bottomAnchor.constraint(equalTo: mainArea.bottomAnchor),
            leftW,

            dividerV.topAnchor.constraint(equalTo: mainArea.topAnchor),
            dividerV.leadingAnchor.constraint(equalTo: leftPanel.trailingAnchor),
            dividerV.widthAnchor.constraint(equalToConstant: 12),
            dividerV.bottomAnchor.constraint(equalTo: mainArea.bottomAnchor),
            divLine.centerXAnchor.constraint(equalTo: dividerV.centerXAnchor),
            divLine.centerYAnchor.constraint(equalTo: dividerV.centerYAnchor),
            divLine.widthAnchor.constraint(equalToConstant: 3),
            divLine.heightAnchor.constraint(equalToConstant: 32),

            rightPanel.topAnchor.constraint(equalTo: mainArea.topAnchor),
            rightPanel.leadingAnchor.constraint(equalTo: dividerV.trailingAnchor),
            rightPanel.trailingAnchor.constraint(equalTo: mainArea.trailingAnchor),
            rightPanel.bottomAnchor.constraint(equalTo: mainArea.bottomAnchor),

            // Left panel internals
            lHeader.topAnchor.constraint(equalTo: leftPanel.topAnchor),
            lHeader.leadingAnchor.constraint(equalTo: leftPanel.leadingAnchor),
            lHeader.trailingAnchor.constraint(equalTo: leftPanel.trailingAnchor),
            lHeader.heightAnchor.constraint(equalToConstant: 34),
            lHLine.leadingAnchor.constraint(equalTo: lHeader.leadingAnchor),
            lHLine.trailingAnchor.constraint(equalTo: lHeader.trailingAnchor),
            lHLine.bottomAnchor.constraint(equalTo: lHeader.bottomAnchor),
            lHLine.heightAnchor.constraint(equalToConstant: 1),
            lDot.leadingAnchor.constraint(equalTo: lHeader.leadingAnchor, constant: 14),
            lDot.centerYAnchor.constraint(equalTo: lHeader.centerYAnchor),
            lDot.widthAnchor.constraint(equalToConstant: 6), lDot.heightAnchor.constraint(equalToConstant: 6),
            lTitle.leadingAnchor.constraint(equalTo: lDot.trailingAnchor, constant: 6),
            lTitle.centerYAnchor.constraint(equalTo: lHeader.centerYAnchor),
            inputSizeL.trailingAnchor.constraint(equalTo: lHeader.trailingAnchor, constant: -14),
            inputSizeL.centerYAnchor.constraint(equalTo: lHeader.centerYAnchor),
            inputSizeL.widthAnchor.constraint(greaterThanOrEqualToConstant: 50),
            inputSizeL.heightAnchor.constraint(equalToConstant: 18),

            inputScroll.topAnchor.constraint(equalTo: lHeader.bottomAnchor),
            inputScroll.leadingAnchor.constraint(equalTo: leftPanel.leadingAnchor),
            inputScroll.trailingAnchor.constraint(equalTo: leftPanel.trailingAnchor),
            inputScroll.bottomAnchor.constraint(equalTo: actionBar.topAnchor),

            actionBar.leadingAnchor.constraint(equalTo: leftPanel.leadingAnchor),
            actionBar.trailingAnchor.constraint(equalTo: leftPanel.trailingAnchor),
            actionBar.bottomAnchor.constraint(equalTo: leftPanel.bottomAnchor),
            actionBar.heightAnchor.constraint(equalToConstant: 38),
            aLine.topAnchor.constraint(equalTo: actionBar.topAnchor),
            aLine.leadingAnchor.constraint(equalTo: actionBar.leadingAnchor),
            aLine.trailingAnchor.constraint(equalTo: actionBar.trailingAnchor),
            aLine.heightAnchor.constraint(equalToConstant: 1),
            fmtBtn.leadingAnchor.constraint(equalTo: actionBar.leadingAnchor, constant: 14),
            fmtBtn.centerYAnchor.constraint(equalTo: actionBar.centerYAnchor),
            fmtBtn.widthAnchor.constraint(greaterThanOrEqualToConstant: 80),
            fmtBtn.heightAnchor.constraint(equalToConstant: 26),
            indentSel.leadingAnchor.constraint(equalTo: fmtBtn.trailingAnchor, constant: 8),
            indentSel.centerYAnchor.constraint(equalTo: actionBar.centerYAnchor),
            shortcutL.trailingAnchor.constraint(equalTo: actionBar.trailingAnchor, constant: -14),
            shortcutL.centerYAnchor.constraint(equalTo: actionBar.centerYAnchor),

            // Right panel internals
            rHeader.topAnchor.constraint(equalTo: rightPanel.topAnchor),
            rHeader.leadingAnchor.constraint(equalTo: rightPanel.leadingAnchor),
            rHeader.trailingAnchor.constraint(equalTo: rightPanel.trailingAnchor),
            rHeader.heightAnchor.constraint(equalToConstant: 34),
            rHLine.leadingAnchor.constraint(equalTo: rHeader.leadingAnchor),
            rHLine.trailingAnchor.constraint(equalTo: rHeader.trailingAnchor),
            rHLine.bottomAnchor.constraint(equalTo: rHeader.bottomAnchor),
            rHLine.heightAnchor.constraint(equalToConstant: 1),
            rDot.leadingAnchor.constraint(equalTo: rHeader.leadingAnchor, constant: 14),
            rDot.centerYAnchor.constraint(equalTo: rHeader.centerYAnchor),
            rDot.widthAnchor.constraint(equalToConstant: 6), rDot.heightAnchor.constraint(equalToConstant: 6),
            rTitle.leadingAnchor.constraint(equalTo: rDot.trailingAnchor, constant: 6),
            rTitle.centerYAnchor.constraint(equalTo: rHeader.centerYAnchor),
            expandBtn.trailingAnchor.constraint(equalTo: outputSizeL.leadingAnchor, constant: -4),
            expandBtn.centerYAnchor.constraint(equalTo: rHeader.centerYAnchor),
            collapseBtn.trailingAnchor.constraint(equalTo: expandBtn.leadingAnchor, constant: -4),
            collapseBtn.centerYAnchor.constraint(equalTo: rHeader.centerYAnchor),
            outputSizeL.trailingAnchor.constraint(equalTo: rHeader.trailingAnchor, constant: -14),
            outputSizeL.centerYAnchor.constraint(equalTo: rHeader.centerYAnchor),
            outputSizeL.widthAnchor.constraint(greaterThanOrEqualToConstant: 50),
            outputSizeL.heightAnchor.constraint(equalToConstant: 18),

            outWrapper.topAnchor.constraint(equalTo: rHeader.bottomAnchor),
            outWrapper.leadingAnchor.constraint(equalTo: rightPanel.leadingAnchor),
            outWrapper.trailingAnchor.constraint(equalTo: rightPanel.trailingAnchor),
            outWrapper.bottomAnchor.constraint(equalTo: rightPanel.bottomAnchor),

            gutterScroll.topAnchor.constraint(equalTo: outWrapper.topAnchor),
            gutterScroll.leadingAnchor.constraint(equalTo: outWrapper.leadingAnchor),
            gutterScroll.widthAnchor.constraint(equalToConstant: 56),
            gutterScroll.bottomAnchor.constraint(equalTo: outWrapper.bottomAnchor),

            outputScroll.topAnchor.constraint(equalTo: outWrapper.topAnchor),
            outputScroll.leadingAnchor.constraint(equalTo: gutterScroll.trailingAnchor),
            outputScroll.trailingAnchor.constraint(equalTo: outWrapper.trailingAnchor),
            outputScroll.bottomAnchor.constraint(equalTo: outWrapper.bottomAnchor),

            // Status bar
            statusV.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            statusV.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            statusV.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            statusV.heightAnchor.constraint(equalToConstant: 28),
            sLine2.topAnchor.constraint(equalTo: statusV.topAnchor),
            sLine2.leadingAnchor.constraint(equalTo: statusV.leadingAnchor),
            sLine2.trailingAnchor.constraint(equalTo: statusV.trailingAnchor),
            sLine2.heightAnchor.constraint(equalToConstant: 1),
            statusDot.leadingAnchor.constraint(equalTo: statusV.leadingAnchor, constant: 16),
            statusDot.centerYAnchor.constraint(equalTo: statusV.centerYAnchor),
            statusDot.widthAnchor.constraint(equalToConstant: 6), statusDot.heightAnchor.constraint(equalToConstant: 6),
            statusL.leadingAnchor.constraint(equalTo: statusDot.trailingAnchor, constant: 6),
            statusL.centerYAnchor.constraint(equalTo: statusV.centerYAnchor),
            hintL.trailingAnchor.constraint(equalTo: statusV.trailingAnchor, constant: -16),
            hintL.centerYAnchor.constraint(equalTo: statusV.centerYAnchor),
        ])

        // Divider drag
        let drag = NSClickGestureRecognizer(target: self, action: #selector(dividerDown(_:)))
        dividerV.addGestureRecognizer(drag)
    }

    func makeBtn(_ title: String, action: Selector) -> NSButton {
        let b = NSButton(title: title, target: self, action: action)
        b.bezelStyle = .roundRect; b.font = NSFont.systemFont(ofSize: 12)
        b.contentTintColor = T.t2; b.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([b.heightAnchor.constraint(equalToConstant: 26)])
        return b
    }

    @objc func dividerDown(_ g: NSClickGestureRecognizer) {
        if g.state == .began { dividerDragging = true }
        else if g.state == .changed, dividerDragging {
            let loc = g.location(in: view)
            let mainX = view.convert(leftPanel.superview!.frame, from: leftPanel.superview).origin.x
            let totalW = leftPanel.superview!.bounds.width
            let ratio = max(0.2, min(0.8, (loc.x - mainX - 12) / totalW))
            leftW.isActive = false
            leftW = leftPanel.widthAnchor.constraint(equalTo: leftPanel.superview!.widthAnchor, multiplier: ratio)
            leftW.isActive = true
        } else if g.state == .ended { dividerDragging = false }
    }

    @objc func outputScrolled() {
        gutterScroll.contentView.scroll(outputScroll.contentView.bounds.origin)
    }

    @objc func gutterClicked(_ g: NSClickGestureRecognizer) {
        let point = g.location(in: gutterTV)
        if let origLine = originalLineForGutterClick(at: point) {
            toggleFoldAtLine(origLine)
        }
    }

    @objc func indentChanged(_ s: NSPopUpButton) {
        switch s.indexOfSelectedItem {
        case 0: indentSize = 2
        case 1: indentSize = 4
        case 2: indentSize = -1 // tab
        default: indentSize = 2
        }
    }

    // MARK: - NSTextViewDelegate
    func textDidChange(_ n: Notification) {
        guard let tv = n.object as? NSTextView, tv === inputTV else { return }
        let len = tv.string.count
        inputSizeL.stringValue = len > 1000 ? String(format: "%.1fk chars", Double(len)/1000) : "\(len) chars"

        // 实时自动格式化（带 debounce）
        formatDebounceTimer?.invalidate()
        formatDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            self?.autoFormat()
        }
    }

    /// 自动格式化（不显示 toast，静默执行）
    func autoFormat() {
        let input = inputTV.string.trimmingCharacters(in: .whitespacesAndNewlines)
        if input.isEmpty {
            outputTV.textStorage?.setAttributedString(NSAttributedString(string: ""))
            gutterTV.string = ""
            lastFormatted = ""; lastParsed = nil; isValid = false
            outputSizeL.stringValue = "0 lines"
            errorBanner.isHidden = true
            statusDot.layer?.backgroundColor = T.t3.cgColor
            statusL.stringValue = "等待输入"
            return
        }
        guard let data = input.data(using: .utf8) else { return }

        let indentStr = indentSize == -1 ? "\t" : String(repeating: " ", count: indentSize)

        // 先尝试标准解析
        if let parsed = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) {
            lastParsed = parsed; isValid = true
            let keyOrder = extractKeyOrder(from: input)
            let formatted = prettyPrint(parsed, indent: indentStr, keyOrder: keyOrder)
            lastFormatted = formatted
            displayOutput(formatted)
            errorBanner.isHidden = true
            statusDot.layer?.backgroundColor = T.green.cgColor
            statusL.stringValue = "✓ JSON 有效"
            return
        }

        // 标准解析失败，尝试宽容修复
        if let (repaired, parsed) = tryRepairJSON(input) {
            lastParsed = parsed; isValid = true
            let formatted = prettyPrint(parsed, indent: indentStr, keyOrder: nil)
            lastFormatted = formatted
            displayOutput(formatted)
            errorL.stringValue = "⚠ 已自动修复: \(repaired)"
            errorBanner.isHidden = false
            statusDot.layer?.backgroundColor = T.yellow.cgColor
            statusL.stringValue = "⚠ 已自动修复并格式化"
            return
        }

        // 无法解析，显示原始输入
        isValid = false; lastParsed = nil
        errorL.stringValue = "JSON 格式错误，无法解析"
        errorBanner.isHidden = false
        displayOutput(input)
        lastFormatted = input
        statusDot.layer?.backgroundColor = T.red.cgColor
        statusL.stringValue = "✗ JSON 无效"
    }

    // MARK: - Actions
    @objc func formatJSON() {
        let input = inputTV.string.trimmingCharacters(in: .whitespacesAndNewlines)
        if input.isEmpty { showToast("请输入 JSON 字符串"); return }
        guard let data = input.data(using: .utf8) else { return }

        let indentStr = indentSize == -1 ? "\t" : String(repeating: " ", count: indentSize)

        // 先尝试标准解析
        if let parsed = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) {
            lastParsed = parsed; isValid = true
            let keyOrder = extractKeyOrder(from: input)
            let formatted = prettyPrint(parsed, indent: indentStr, keyOrder: keyOrder)
            lastFormatted = formatted
            displayOutput(formatted)
            errorBanner.isHidden = true
            statusDot.layer?.backgroundColor = T.green.cgColor
            statusL.stringValue = "✓ JSON 有效"
            showToast("✓ 格式化成功")
            return
        }

        // 标准解析失败，尝试宽容修复
        if let (repaired, parsed) = tryRepairJSON(input) {
            lastParsed = parsed; isValid = true
            let formatted = prettyPrint(parsed, indent: indentStr, keyOrder: nil)
            lastFormatted = formatted
            displayOutput(formatted)
            errorL.stringValue = "⚠ 已自动修复: \(repaired)"
            errorBanner.isHidden = false
            statusDot.layer?.backgroundColor = T.yellow.cgColor
            statusL.stringValue = "⚠ 已自动修复并格式化"
            showToast("⚠ 已自动修复并格式化")
            return
        }

        // 完全无法解析
        isValid = false; lastParsed = nil
        let msg = "JSON 格式错误，无法解析"
        errorL.stringValue = msg; errorBanner.isHidden = false
        displayOutput(input)
        lastFormatted = input
        statusDot.layer?.backgroundColor = T.red.cgColor
        statusL.stringValue = "✗ JSON 无效"
        showToast("⚠ JSON 格式有误")
    }

    /// 尝试修复常见的 JSON 错误
    func tryRepairJSON(_ input: String) -> (String, Any)? {
        var repairLog: [String] = []
        var text = input

        // 修复策略1: 去掉尾部多余的 } 或 ]
        if let result = tryTrimTrailing(text) {
            repairLog.append("去除了尾部多余的括号")
            return (repairLog.joined(separator: "; "), result)
        }

        // 修复策略2: 补全缺少的 } 或 ]
        if let result = tryAddMissingBrackets(text) {
            repairLog.append("补全了缺少的括号")
            return (repairLog.joined(separator: "; "), result)
        }

        // 修复策略3: 去掉尾部逗号 (trailing comma)
        text = removeTrailingCommas(input)
        if text != input {
            if let data = text.data(using: .utf8),
               let parsed = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) {
                repairLog.append("去除了尾部逗号")
                return (repairLog.joined(separator: "; "), parsed)
            }
        }

        // 修复策略4: 给无引号的 key 加上引号
        text = fixUnquotedKeys(input)
        if text != input {
            if let data = text.data(using: .utf8),
               let parsed = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) {
                repairLog.append("修复了未加引号的键名")
                return (repairLog.joined(separator: "; "), parsed)
            }
        }

        // 修复策略5: 组合修复
        text = fixUnquotedKeys(removeTrailingCommas(input))
        if let result = tryTrimTrailing(text) {
            return ("综合修复", result)
        }
        if let result = tryAddMissingBrackets(text) {
            return ("综合修复", result)
        }
        if let data = text.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) {
            return ("综合修复", parsed)
        }

        // 修复策略6: 单引号替换为双引号
        text = input.replacingOccurrences(of: "'", with: "\"")
        if text != input {
            if let data = text.data(using: .utf8),
               let parsed = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) {
                return ("单引号替换为双引号", parsed)
            }
            // 再尝试组合
            text = fixUnquotedKeys(removeTrailingCommas(text))
            if let result = tryTrimTrailing(text) { return ("综合修复（含引号替换）", result) }
            if let result = tryAddMissingBrackets(text) { return ("综合修复（含引号替换）", result) }
        }

        return nil
    }

    func tryTrimTrailing(_ input: String) -> Any? {
        var text = input
        // 逐步从末尾去掉 } 或 ]，看能否解析
        while text.hasSuffix("}") || text.hasSuffix("]") {
            let trimmed = String(text.dropLast())
            if let data = trimmed.data(using: .utf8),
               let parsed = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) {
                return parsed
            }
            text = trimmed
        }
        return nil
    }

    func tryAddMissingBrackets(_ input: String) -> Any? {
        // 统计未匹配的括号
        var braceCount = 0, bracketCount = 0
        var inString = false, escaped = false
        for c in input {
            if escaped { escaped = false; continue }
            if c == "\\" && inString { escaped = true; continue }
            if c == "\"" { inString = !inString; continue }
            if inString { continue }
            switch c {
            case "{": braceCount += 1
            case "}": braceCount -= 1
            case "[": bracketCount += 1
            case "]": bracketCount -= 1
            default: break
            }
        }
        if braceCount == 0 && bracketCount == 0 { return nil }
        var fixed = input
        for _ in 0..<max(0, braceCount) { fixed += "}" }
        for _ in 0..<max(0, bracketCount) { fixed += "]" }
        if let data = fixed.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) {
            return parsed
        }
        return nil
    }

    func removeTrailingCommas(_ input: String) -> String {
        // 去除 ,} 和 ,] 中的逗号（允许中间有空白）
        var result = input
        let patterns = [
            (try? NSRegularExpression(pattern: ",\\s*}", options: []), "}"),
            (try? NSRegularExpression(pattern: ",\\s*\\]", options: []), "]"),
        ]
        for (regex, replacement) in patterns {
            if let regex = regex {
                result = regex.stringByReplacingMatches(in: result, options: [], range: NSRange(result.startIndex..., in: result), withTemplate: replacement)
            }
        }
        return result
    }

    func fixUnquotedKeys(_ input: String) -> String {
        // 匹配 {key: 或 ,key: 形式，给 key 加上双引号
        guard let regex = try? NSRegularExpression(pattern: "([{,])\\s*([a-zA-Z_$][a-zA-Z0-9_$]*)\\s*:", options: []) else { return input }
        let nsInput = input as NSString
        var result = input
        let matches = regex.matches(in: input, options: [], range: NSRange(location: 0, length: nsInput.length))
        // 逆序替换避免偏移
        for match in matches.reversed() {
            if match.numberOfRanges >= 3 {
                let keyRange = match.range(at: 2)
                let key = nsInput.substring(with: keyRange)
                // 确保不是已经在字符串内
                let fullRange = match.range
                let prefix = nsInput.substring(with: NSRange(location: fullRange.location, length: keyRange.location - fullRange.location))
                let replacement = "\(prefix)\"\(key)\":"
                result = (result as NSString).replacingCharacters(in: fullRange, with: replacement)
            }
        }
        return result
    }

    func displayOutput(_ json: String) {
        fullFormattedLines = json.components(separatedBy: "\n")
        // Build fold regions from the formatted output
        foldRegions = buildFoldRegions(from: fullFormattedLines)
        renderWithFolding()
    }

    /// Build fold regions by finding matching bracket pairs
    func buildFoldRegions(from lines: [String]) -> [FoldRegion] {
        var regions: [FoldRegion] = []
        var stack: [(line: Int, char: Character)] = []
        for (i, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Check for opening brackets at the end of a line
            if trimmed.hasSuffix("{") || trimmed.hasSuffix("[") {
                let lastChar: Character = trimmed.hasSuffix("{") ? "{" : "["
                stack.append((line: i, char: lastChar))
            }
            // Check for closing brackets
            let firstNonSpace = trimmed.first
            if firstNonSpace == "}" || firstNonSpace == "]" {
                if let last = stack.last {
                    let matching: Character = last.char == "{" ? "}" : "]"
                    if firstNonSpace == matching {
                        stack.removeLast()
                        if i > last.line { // Only create region if more than one line
                            regions.append(FoldRegion(startLine: last.line, endLine: i, collapsed: false))
                        }
                    }
                }
            }
        }
        return regions
    }

    /// Render the output considering fold states
    func renderWithFolding() {
        // Determine which lines are hidden due to folding
        var hiddenLines = Set<Int>()
        // Sort fold regions by startLine for consistent processing
        let sortedRegions = foldRegions.enumerated().sorted { $0.element.startLine < $1.element.startLine }
        for (_, region) in sortedRegions {
            if region.collapsed {
                // Hide lines from startLine+1 to endLine (inclusive)
                for line in (region.startLine + 1)...region.endLine {
                    hiddenLines.insert(line)
                }
            }
        }

        // Build visible text
        var visibleLines: [String] = []
        var visibleLineNumbers: [Int] = [] // original 1-based line numbers
        var gutterSymbols: [String] = []

        for (i, line) in fullFormattedLines.enumerated() {
            if hiddenLines.contains(i) { continue }

            // Check if this line starts a collapsed region
            let collapsedRegion = foldRegions.first { $0.startLine == i && $0.collapsed }
            if let region = collapsedRegion {
                // Show the opening line with a collapse indicator
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                let isArray = trimmed.hasSuffix("[")
                let closingBracket: String = isArray ? "]" : "}"
                // Find if closing bracket has a comma
                let closingLine = fullFormattedLines[region.endLine].trimmingCharacters(in: .whitespaces)
                let trailingComma = closingLine.hasSuffix(",") ? "," : ""
                // Count children for the collapsed region
                let childCount = countDirectChildren(startLine: region.startLine, endLine: region.endLine)
                let summary: String
                if isArray {
                    summary = " \(childCount) items "
                } else {
                    summary = " \(childCount) keys "
                }
                let collapsedLine = line + summary + closingBracket + trailingComma
                visibleLines.append(collapsedLine)
            } else {
                visibleLines.append(line)
            }
            visibleLineNumbers.append(i + 1)

            // Gutter symbol
            let foldable = foldRegions.first { $0.startLine == i }
            if let fr = foldable {
                gutterSymbols.append(fr.collapsed ? "▶" : "▼")
            } else {
                gutterSymbols.append("")
            }
        }

        let displayText = visibleLines.joined(separator: "\n")
        let attr = highlight(displayText)

        // Style the fold summary text (e.g., "3 items", "5 keys") in collapsed lines
        let displayNS = displayText as NSString
        for (_, region) in foldRegions.enumerated() where region.collapsed {
            // Find the collapsed summary pattern in display text
            let patterns = ["items", "keys"]
            for pat in patterns {
                // Search for " N pat " pattern (N is a number)
                if let regex = try? NSRegularExpression(pattern: " \\d+ \(pat) ", options: []) {
                    let matches = regex.matches(in: displayText, options: [], range: NSRange(location: 0, length: displayNS.length))
                    for m in matches {
                        attr.addAttribute(.foregroundColor, value: T.t3, range: m.range)
                        attr.addAttribute(.font, value: NSFont.systemFont(ofSize: 12, weight: .regular), range: m.range)
                    }
                }
            }
        }

        outputTV.textStorage?.setAttributedString(attr)
        outputSizeL.stringValue = "\(fullFormattedLines.count) lines"

        // Build gutter with fold indicators using attributed string
        let gutterAttr = NSMutableAttributedString()
        let gutterFont = T.monoSm
        let normalAttrs: [NSAttributedString.Key: Any] = [.font: gutterFont, .foregroundColor: T.t3]
        let foldIconFont = NSFont.systemFont(ofSize: 14, weight: .bold)
        let expandedAttrs: [NSAttributedString.Key: Any] = [
            .font: foldIconFont,
            .foregroundColor: T.accent
        ]
        let collapsedAttrs: [NSAttributedString.Key: Any] = [
            .font: foldIconFont,
            .foregroundColor: T.peach
        ]

        for (idx, lineNum) in visibleLineNumbers.enumerated() {
            let symbol = gutterSymbols[idx]
            if !symbol.isEmpty {
                let icon = symbol == "▼" ? "⌵" : "›"
                let iconAttrs = symbol == "▼" ? expandedAttrs : collapsedAttrs
                gutterAttr.append(NSAttributedString(string: icon, attributes: iconAttrs))
                gutterAttr.append(NSAttributedString(string: "\(lineNum)\n", attributes: normalAttrs))
            } else {
                gutterAttr.append(NSAttributedString(string: " \(lineNum)\n", attributes: normalAttrs))
            }
        }
        gutterTV.textStorage?.setAttributedString(gutterAttr)
    }

    /// Count direct children in a fold region (items in array, or keys in object)
    func countDirectChildren(startLine: Int, endLine: Int) -> Int {
        // We need to count top-level items between startLine and endLine
        // by tracking bracket nesting depth
        var count = 0
        var depth = 0
        for lineIdx in (startLine + 1)..<endLine {
            let trimmed = fullFormattedLines[lineIdx].trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            // At depth 0, each non-bracket line (or line that starts content) is a child
            if depth == 0 {
                count += 1
            }
            // Track nesting: count opening and closing brackets
            for ch in trimmed {
                if ch == "{" || ch == "[" { depth += 1 }
                else if ch == "}" || ch == "]" { depth -= 1 }
            }
        }
        return count
    }

    /// Toggle fold at a given visible line index
    func toggleFoldAtLine(_ originalLineIdx: Int) {
        guard let regionIdx = foldRegions.firstIndex(where: { $0.startLine == originalLineIdx }) else { return }
        foldRegions[regionIdx].collapsed.toggle()
        renderWithFolding()
        // Refresh search if active
        if !lastSearchQuery.isEmpty { refreshSearchHighlights() }
    }

    /// Map a click in gutter to the original line index
    func originalLineForGutterClick(at point: NSPoint) -> Int? {
        // Get the character index at the click point in gutterTV
        guard let layoutManager = gutterTV.layoutManager,
              let textContainer = gutterTV.textContainer else { return nil }
        let textPoint = NSPoint(x: point.x - gutterTV.textContainerInset.width,
                                y: point.y - gutterTV.textContainerInset.height)
        let charIdx = layoutManager.characterIndex(for: textPoint, in: textContainer, fractionOfDistanceBetweenInsertionPoints: nil)
        let gutterStr = gutterTV.string as NSString
        if charIdx >= gutterStr.length { return nil }

        // Find which line this character is on
        let lineRange = gutterStr.lineRange(for: NSRange(location: charIdx, length: 0))
        let lineStr = gutterStr.substring(with: lineRange).trimmingCharacters(in: .whitespacesAndNewlines)

        // Extract the line number (remove fold symbols)
        let cleaned = lineStr.replacingOccurrences(of: "›", with: "").replacingOccurrences(of: "⌵", with: "").trimmingCharacters(in: .whitespaces)
        guard let lineNum = Int(cleaned) else { return nil }
        return lineNum - 1 // Convert to 0-based
    }

    func updateGutter(_ count: Int) {
        var text = ""
        for i in 1...max(count, 1) { text += "\(i)\n" }
        gutterTV.string = text
    }

    @objc func minifyJSON() {
        let input = inputTV.string.trimmingCharacters(in: .whitespacesAndNewlines)
        if input.isEmpty { showToast("请先输入 JSON"); return }
        guard let data = input.data(using: .utf8) else { return }
        do {
            let parsed = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
            let minData = try JSONSerialization.data(withJSONObject: parsed, options: [.fragmentsAllowed])
            let minified = String(data: minData, encoding: .utf8) ?? ""
            inputTV.string = minified
            textDidChange(Notification(name: NSText.didChangeNotification, object: inputTV))
            errorBanner.isHidden = true
            statusDot.layer?.backgroundColor = T.green.cgColor
            statusL.stringValue = "✓ 已删除空格"
            showToast("✓ 已删除空格")
        } catch { showToast("⚠ JSON 无效，无法压缩") }
    }

    @objc func minifyAndEscape() {
        let input = inputTV.string.trimmingCharacters(in: .whitespacesAndNewlines)
        if input.isEmpty { showToast("请先输入 JSON"); return }
        guard let data = input.data(using: .utf8) else { return }
        do {
            let parsed = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
            let minData = try JSONSerialization.data(withJSONObject: parsed, options: [.fragmentsAllowed])
            let minified = String(data: minData, encoding: .utf8) ?? ""
            guard let escData = try? JSONSerialization.data(withJSONObject: minified, options: [.fragmentsAllowed]) else { return }
            var escaped = String(data: escData, encoding: .utf8) ?? ""
            if escaped.hasPrefix("\"") && escaped.hasSuffix("\"") { escaped = String(escaped.dropFirst().dropLast()) }
            inputTV.string = escaped
            textDidChange(Notification(name: NSText.didChangeNotification, object: inputTV))
            errorBanner.isHidden = true
            statusDot.layer?.backgroundColor = T.green.cgColor
            statusL.stringValue = "✓ 已删除空格并转义"
            showToast("✓ 已删除空格并转义")
        } catch { showToast("⚠ JSON 无效，无法处理") }
    }

    @objc func unescapeJSON() {
        let input = inputTV.string.trimmingCharacters(in: .whitespacesAndNewlines)
        if input.isEmpty { showToast("请先输入内容"); return }
        var unescaped: String
        if input.hasPrefix("\"") && input.hasSuffix("\"") {
            guard let d = input.data(using: .utf8),
                  let r = try? JSONSerialization.jsonObject(with: d, options: [.fragmentsAllowed]) as? String else {
                showToast("⚠ 无法去除转义"); return
            }
            unescaped = r
        } else {
            let quoted = "\"" + input + "\""
            guard let d = quoted.data(using: .utf8),
                  let r = try? JSONSerialization.jsonObject(with: d, options: [.fragmentsAllowed]) as? String else {
                showToast("⚠ 无法去除转义，请检查输入格式"); return
            }
            unescaped = r
        }
        inputTV.string = unescaped
        textDidChange(Notification(name: NSText.didChangeNotification, object: inputTV))
        if let d = unescaped.data(using: .utf8), let _ = try? JSONSerialization.jsonObject(with: d, options: [.fragmentsAllowed]) {
            formatJSON(); showToast("✓ 已去除转义并格式化")
        } else {
            lastFormatted = unescaped
            let attr = NSMutableAttributedString(string: unescaped, attributes: [.font: T.mono, .foregroundColor: T.t1])
            outputTV.textStorage?.setAttributedString(attr)
            statusDot.layer?.backgroundColor = T.green.cgColor
            statusL.stringValue = "✓ 已去除转义"
            showToast("✓ 已去除转义")
        }
    }

    @objc func copyOutput() {
        if lastFormatted.isEmpty { showToast("没有可复制的内容"); return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lastFormatted, forType: .string)
        showToast("✓ 已复制到剪贴板")
    }

    @objc func clearAll() {
        inputTV.string = ""
        outputTV.textStorage?.setAttributedString(NSAttributedString(string: ""))
        gutterTV.string = ""
        lastFormatted = ""; lastParsed = nil; isValid = false
        foldRegions = []; fullFormattedLines = []
        inputSizeL.stringValue = "0 chars"; outputSizeL.stringValue = "0 lines"
        errorBanner.isHidden = true
        statusDot.layer?.backgroundColor = T.t3.cgColor
        statusL.stringValue = "等待输入"
        view.window?.makeFirstResponder(inputTV)
    }

    @objc func loadSample() {
        let sample: [String: Any] = [
            "name": "JSON Formatter", "version": "1.0.0",
            "description": "一个强大的 JSON 格式化工具",
            "features": ["格式化", "语法高亮", "错误检测", "折叠展开", "搜索"],
            "author": ["name": "Alfred Plugin", "email": "example@test.com"],
            "settings": ["indent": 2, "theme": "light", "autoFormat": true],
            "data": [["id": 1, "title": "任务一", "done": false], ["id": 2, "title": "任务二", "done": true]],
            "tags": NSNull(), "count": 42, "active": true,
        ] as [String: Any]
        guard let d = try? JSONSerialization.data(withJSONObject: sample, options: []),
              let s = String(data: d, encoding: .utf8) else { return }
        inputTV.string = s
        textDidChange(Notification(name: NSText.didChangeNotification, object: inputTV))
        formatJSON()
    }

    @objc func expandAll() {
        for i in 0..<foldRegions.count { foldRegions[i].collapsed = false }
        renderWithFolding()
        if !lastSearchQuery.isEmpty { refreshSearchHighlights() }
        showToast("全部展开")
    }
    @objc func collapseAll() {
        // Only collapse top-level regions (regions not contained within another region)
        for i in 0..<foldRegions.count { foldRegions[i].collapsed = true }
        renderWithFolding()
        if !lastSearchQuery.isEmpty { refreshSearchHighlights() }
        showToast("全部折叠")
    }

    // MARK: - Search
    @objc func openSearch() {
        searchBar.isHidden = false
        view.window?.makeFirstResponder(searchField)
    }
    @objc func closeSearch() {
        searchBar.isHidden = true
        searchMatches = []; inputSearchMatches = []; searchIdx = -1; searchInfoL.stringValue = ""
        lastSearchQuery = ""
        clearSearchHighlights()
    }
    @objc func performSearch() {
        let q = searchField.stringValue.trimmingCharacters(in: .whitespaces)
        if q.isEmpty { clearSearchHighlights(); searchMatches = []; inputSearchMatches = []; searchIdx = -1; lastSearchQuery = ""; searchInfoL.stringValue = ""; return }
        // If same query and already have results, jump to next match
        if q == lastSearchQuery && (searchMatches.count + inputSearchMatches.count) > 0 {
            searchNext()
            return
        }
        lastSearchQuery = q
        clearSearchHighlights()
        // Search in output
        let outText = outputTV.string as NSString
        let qLower = q.lowercased()
        let outTextLower = outText.lowercased as NSString
        searchMatches = []; var pos = 0
        while true {
            let found = outTextLower.range(of: qLower, options: [], range: NSRange(location: pos, length: outTextLower.length - pos))
            if found.location == NSNotFound { break }
            searchMatches.append(found); pos = found.location + found.length
        }
        // Search in input
        let inText = inputTV.string as NSString
        let inTextLower = inText.lowercased as NSString
        inputSearchMatches = []; pos = 0
        while true {
            let found = inTextLower.range(of: qLower, options: [], range: NSRange(location: pos, length: inTextLower.length - pos))
            if found.location == NSNotFound { break }
            inputSearchMatches.append(found); pos = found.location + found.length
        }
        let total = searchMatches.count + inputSearchMatches.count
        if total == 0 {
            searchIdx = -1; searchInOutput = true; searchInfoL.stringValue = "无结果"
        } else {
            searchIdx = 0
            // Start with output matches if available, otherwise input
            searchInOutput = !searchMatches.isEmpty
            highlightSearchMatches()
            let info = searchInOutput ? "1 / \(total) (右)" : "1 / \(total) (左)"
            searchInfoL.stringValue = info
            scrollToCurrentMatch()
        }
    }
    @objc func searchNext() {
        let total = searchMatches.count + inputSearchMatches.count
        if total == 0 { return }
        // Navigate: output matches first, then input matches
        if searchInOutput {
            if searchIdx + 1 < searchMatches.count {
                searchIdx += 1
            } else {
                // Switch to input matches
                if !inputSearchMatches.isEmpty {
                    searchInOutput = false; searchIdx = 0
                } else {
                    searchIdx = 0 // wrap around output
                }
            }
        } else {
            if searchIdx + 1 < inputSearchMatches.count {
                searchIdx += 1
            } else {
                // Switch to output matches
                if !searchMatches.isEmpty {
                    searchInOutput = true; searchIdx = 0
                } else {
                    searchIdx = 0 // wrap around input
                }
            }
        }
        highlightSearchMatches()
        let globalIdx = searchInOutput ? searchIdx : searchMatches.count + searchIdx
        let side = searchInOutput ? "右" : "左"
        searchInfoL.stringValue = "\(globalIdx + 1) / \(total) (\(side))"
        scrollToCurrentMatch()
    }
    @objc func searchPrev() {
        let total = searchMatches.count + inputSearchMatches.count
        if total == 0 { return }
        if searchInOutput {
            if searchIdx > 0 {
                searchIdx -= 1
            } else {
                // Switch to input matches (last one)
                if !inputSearchMatches.isEmpty {
                    searchInOutput = false; searchIdx = inputSearchMatches.count - 1
                } else {
                    searchIdx = searchMatches.count - 1 // wrap around output
                }
            }
        } else {
            if searchIdx > 0 {
                searchIdx -= 1
            } else {
                // Switch to output matches (last one)
                if !searchMatches.isEmpty {
                    searchInOutput = true; searchIdx = searchMatches.count - 1
                } else {
                    searchIdx = inputSearchMatches.count - 1 // wrap around input
                }
            }
        }
        highlightSearchMatches()
        let globalIdx = searchInOutput ? searchIdx : searchMatches.count + searchIdx
        let side = searchInOutput ? "右" : "左"
        searchInfoL.stringValue = "\(globalIdx + 1) / \(total) (\(side))"
        scrollToCurrentMatch()
    }
    func highlightSearchMatches() {
        // Highlight output matches
        let outStorage = outputTV.textStorage ?? NSTextStorage()
        let outText = outputTV.string
        outStorage.setAttributedString(highlight(outText))
        for (i, r) in searchMatches.enumerated() {
            let isCurrent = searchInOutput && i == searchIdx
            outStorage.addAttribute(.backgroundColor, value: isCurrent ? searchCurrentColor : searchHighlightColor, range: r)
        }
        // Highlight input matches
        let inStorage = inputTV.textStorage ?? NSTextStorage()
        let inText = inputTV.string
        inStorage.setAttributedString(NSMutableAttributedString(string: inText, attributes: [.font: T.mono, .foregroundColor: T.t1]))
        for (i, r) in inputSearchMatches.enumerated() {
            let isCurrent = !searchInOutput && i == searchIdx
            inStorage.addAttribute(.backgroundColor, value: isCurrent ? searchCurrentColor : searchHighlightColor, range: r)
        }
    }
    func clearSearchHighlights() {
        let outText = outputTV.string
        if !outText.isEmpty { outputTV.textStorage?.setAttributedString(highlight(outText)) }
        let inText = inputTV.string
        if !inText.isEmpty {
            inputTV.textStorage?.setAttributedString(NSMutableAttributedString(string: inText, attributes: [.font: T.mono, .foregroundColor: T.t1]))
        }
    }
    func scrollToCurrentMatch() {
        if searchInOutput {
            guard searchIdx >= 0 && searchIdx < searchMatches.count else { return }
            outputTV.scrollRangeToVisible(searchMatches[searchIdx])
        } else {
            guard searchIdx >= 0 && searchIdx < inputSearchMatches.count else { return }
            inputTV.scrollRangeToVisible(inputSearchMatches[searchIdx])
        }
    }
    /// Re-run search on current displayed text (after fold/unfold)
    func refreshSearchHighlights() {
        let q = lastSearchQuery
        if q.isEmpty { return }
        let qLower = q.lowercased()
        // Re-search in output (which may have changed due to folding)
        let outText = outputTV.string as NSString
        let outTextLower = outText.lowercased as NSString
        searchMatches = []; var pos = 0
        while true {
            let found = outTextLower.range(of: qLower, options: [], range: NSRange(location: pos, length: outTextLower.length - pos))
            if found.location == NSNotFound { break }
            searchMatches.append(found); pos = found.location + found.length
        }
        // Input matches don't change with folding, but re-count total
        let total = searchMatches.count + inputSearchMatches.count
        if total == 0 {
            searchIdx = -1; searchInOutput = true; searchInfoL.stringValue = "无结果"
        } else {
            // Reset to first match
            searchIdx = 0
            searchInOutput = !searchMatches.isEmpty
            highlightSearchMatches()
            let side = searchInOutput ? "右" : "左"
            searchInfoL.stringValue = "1 / \(total) (\(side))"
            scrollToCurrentMatch()
        }
    }
    @objc func copyMatchedValues() {
        guard let q = searchField?.stringValue.trimmingCharacters(in: .whitespaces), !q.isEmpty, let data = lastParsed else {
            showToast("无搜索结果"); return
        }
        let entries = findMatchingEntries(data, query: q, path: "$")
        if entries.isEmpty { showToast("未找到匹配的键"); return }
        let text = entries.map { e -> String in
            let v = e.value; if v is NSNull { return "null" }
            if let s = v as? String { return s }
            return String(describing: v)
        }.joined(separator: "\n")
        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(text, forType: .string)
        showToast("✓ 已复制 \(entries.count) 个值")
    }
    @objc func copyMatchedPairs() {
        guard let q = searchField?.stringValue.trimmingCharacters(in: .whitespaces), !q.isEmpty, let data = lastParsed else {
            showToast("无搜索结果"); return
        }
        let entries = findMatchingEntries(data, query: q, path: "$")
        if entries.isEmpty { showToast("未找到匹配的键"); return }
        let text = entries.map { e -> String in
            let v = e.value; var vs: String
            if v is NSNull { vs = "null" } else if let s = v as? String {
                if let d = try? JSONSerialization.data(withJSONObject: s, options: [.fragmentsAllowed]),
                   let js = String(data: d, encoding: .utf8) { vs = js } else { vs = "\"\(s)\"" }
            }
            else { vs = String(describing: v) }
            return "\"\(e.key)\": \(vs)"
        }.joined(separator: "\n")
        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(text, forType: .string)
        showToast("✓ 已复制 \(entries.count) 个键值对")
    }
    func findMatchingEntries(_ data: Any, query: String, path: String) -> [(key: String, value: Any)] {
        var results: [(key: String, value: Any)] = []
        let qL = query.lowercased()
        if let dict = data as? [String: Any] {
            for (k, v) in dict {
                if k.lowercased().contains(qL) { results.append((key: k, value: v)) }
                if v is [String: Any] || v is [Any] { results.append(contentsOf: findMatchingEntries(v, query: query, path: path + "." + k)) }
            }
        } else if let arr = data as? [Any] {
            for (i, item) in arr.enumerated() {
                results.append(contentsOf: findMatchingEntries(item, query: query, path: path + "[\(i)]"))
            }
        }
        return results
    }

    // MARK: - JSON Pretty Print
    func prettyPrint(_ value: Any, indent: String, keyOrder: [[String]]? = nil) -> String {
        return renderVal(value, depth: 0, indent: indent, keyOrder: keyOrder, keyOrderIdx: KeyOrderIdx())
    }
    /// Mutable index counter for traversing keyOrder array
    class KeyOrderIdx { var idx = 0 }
    func renderVal(_ value: Any, depth: Int, indent: String, keyOrder: [[String]]?, keyOrderIdx: KeyOrderIdx) -> String {
        let prefix = String(repeating: indent, count: depth)
        let child = String(repeating: indent, count: depth + 1)
        if value is NSNull { return "null" }
        if let n = value as? NSNumber {
            if CFBooleanGetTypeID() == CFGetTypeID(n) { return n.boolValue ? "true" : "false" }
            if n.doubleValue == Double(n.intValue) && !"\(n)".contains(".") { return "\(n.intValue)" }
            return "\(n)"
        }
        if let s = value as? String { return escStr(s) }
        if let arr = value as? [Any] {
            if arr.isEmpty { return "[]" }
            var lines = ["["]
            for (i, item) in arr.enumerated() {
                let comma = i < arr.count - 1 ? "," : ""
                lines.append("\(child)\(renderVal(item, depth: depth + 1, indent: indent, keyOrder: keyOrder, keyOrderIdx: keyOrderIdx))\(comma)")
            }
            lines.append("\(prefix)]"); return lines.joined(separator: "\n")
        }
        if let dict = value as? [String: Any] {
            if dict.isEmpty { return "{}" }
            // Use original key order if available, otherwise keep dict.keys order (no sorting)
            let keys: [String]
            if let order = keyOrder, keyOrderIdx.idx < order.count {
                let origOrder = order[keyOrderIdx.idx]
                keyOrderIdx.idx += 1
                // Use origOrder but include any keys that might not be in origOrder
                let origSet = Set(origOrder)
                let extra = dict.keys.filter { !origSet.contains($0) }
                keys = origOrder.filter { dict[$0] != nil } + extra
            } else {
                keys = Array(dict.keys)
            }
            var lines = ["{"]
            for (i, key) in keys.enumerated() {
                let comma = i < keys.count - 1 ? "," : ""
                let val = dict[key]!
                let rendered = renderVal(val, depth: depth + 1, indent: indent, keyOrder: keyOrder, keyOrderIdx: keyOrderIdx)
                if rendered.contains("\n") {
                    let rLines = rendered.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
                    var r = "\(child)\(escStr(key)): \(rLines[0])"
                    for li in 1..<rLines.count { r += "\n\(rLines[li])" }
                    r += comma; lines.append(r)
                } else {
                    lines.append("\(child)\(escStr(key)): \(rendered)\(comma)")
                }
            }
            lines.append("\(prefix)}"); return lines.joined(separator: "\n")
        }
        return "\(value)"
    }
    func escStr(_ s: String) -> String {
        var r = "\""
        for c in s {
            switch c {
            case "\"": r += "\\\""; case "\\": r += "\\\\"
            case "\n": r += "\\n"; case "\r": r += "\\r"; case "\t": r += "\\t"
            default:
                if let a = c.asciiValue, a < 0x20 { r += String(format: "\\u%04x", a) } else { r.append(c) }
            }
        }
        r += "\""; return r
    }

    /// Extract key order from original JSON string for all objects (in DFS pre-order)
    /// The result array must match the order that renderVal consumes keyOrder entries:
    /// each object's keys are recorded BEFORE recursing into its values.
    func extractKeyOrder(from json: String) -> [[String]] {
        var result: [[String]] = []
        let chars = Array(json)
        let len = chars.count
        var i = 0

        func skipWhitespace() {
            while i < len && (chars[i] == " " || chars[i] == "\n" || chars[i] == "\r" || chars[i] == "\t") { i += 1 }
        }
        func readString() -> String? {
            guard i < len && chars[i] == "\"" else { return nil }
            i += 1 // skip opening "
            var s = ""
            while i < len {
                let c = chars[i]
                if c == "\\" {
                    i += 1
                    guard i < len else { break }
                    let esc = chars[i]
                    switch esc {
                    case "\"": s.append("\"")
                    case "\\": s.append("\\")
                    case "/": s.append("/")
                    case "n": s.append("\n")
                    case "r": s.append("\r")
                    case "t": s.append("\t")
                    case "b": s.append("\u{08}")
                    case "f": s.append("\u{0C}")
                    case "u":
                        // Parse \uXXXX
                        i += 1
                        var hex = ""
                        for _ in 0..<4 {
                            guard i < len else { break }
                            hex.append(chars[i]); i += 1
                        }
                        if let code = UInt32(hex, radix: 16), let scalar = Unicode.Scalar(code) {
                            s.append(Character(scalar))
                        }
                        continue // already advanced i
                    default: s.append(esc) // unknown escape, keep as-is
                    }
                    i += 1; continue
                }
                if c == "\"" { i += 1; return s }
                s.append(c); i += 1
            }
            return s
        }
        func skipValue() {
            skipWhitespace()
            guard i < len else { return }
            let c = chars[i]
            if c == "\"" { _ = readString() }
            else if c == "{" { scanObject() }
            else if c == "[" { scanArray() }
            else { while i < len && chars[i] != "," && chars[i] != "}" && chars[i] != "]" && chars[i] != " " && chars[i] != "\n" && chars[i] != "\r" && chars[i] != "\t" { i += 1 } }
        }
        func scanObject() {
            guard i < len && chars[i] == "{" else { return }
            i += 1 // skip {
            skipWhitespace()

            // Two-pass approach: first pass collects keys, second pass recurses into values
            // But we need to do it in one pass. Instead, reserve a slot in result first,
            // collect keys while scanning, then fill the slot.
            let slotIndex = result.count
            result.append([]) // reserve slot for this object's keys

            if i < len && chars[i] == "}" { i += 1; return } // empty object
            var keys: [String] = []
            while i < len {
                skipWhitespace()
                if i < len && chars[i] == "}" { i += 1; break }
                if let key = readString() { keys.append(key) }
                skipWhitespace()
                if i < len && chars[i] == ":" { i += 1 }
                skipValue() // this may recursively append more entries to result
                skipWhitespace()
                if i < len && chars[i] == "," { i += 1 }
            }
            result[slotIndex] = keys // fill the reserved slot
        }
        func scanArray() {
            guard i < len && chars[i] == "[" else { return }
            i += 1 // skip [
            skipWhitespace()
            if i < len && chars[i] == "]" { i += 1; return }
            while i < len {
                skipWhitespace()
                if i < len && chars[i] == "]" { i += 1; break }
                skipValue()
                skipWhitespace()
                if i < len && chars[i] == "," { i += 1 }
            }
        }

        skipWhitespace()
        if i < len {
            if chars[i] == "{" { scanObject() }
            else if chars[i] == "[" { scanArray() }
        }
        return result
    }

    // MARK: - Syntax Highlighting
    func highlight(_ json: String) -> NSMutableAttributedString {
        let attr = NSMutableAttributedString(string: json, attributes: [.font: T.mono, .foregroundColor: T.t1])
        let text = json as NSString; let len = text.length; var i = 0
        while i < len {
            let c = text.character(at: i)
            if c == UInt16(UnicodeScalar("\"").value) {
                let start = i; i += 1
                while i < len {
                    let cc = text.character(at: i)
                    if cc == UInt16(UnicodeScalar("\\").value) { i += 2; continue }
                    if cc == UInt16(UnicodeScalar("\"").value) { i += 1; break }
                    i += 1
                }
                let range = NSRange(location: start, length: i - start)
                var isKey = false; var j = i
                while j < len {
                    let nc = text.character(at: j)
                    if nc == UInt16(UnicodeScalar(" ").value) || nc == UInt16(UnicodeScalar("\n").value) ||
                       nc == UInt16(UnicodeScalar("\r").value) || nc == UInt16(UnicodeScalar("\t").value) { j += 1; continue }
                    if nc == UInt16(UnicodeScalar(":").value) { isKey = true }; break
                }
                attr.addAttribute(.foregroundColor, value: isKey ? T.jKey : T.jStr, range: range)
                continue
            }
            let ch = Character(UnicodeScalar(c)!)
            if ch == "-" || ch.isNumber {
                let start = i; if ch == "-" { i += 1 }
                while i < len && (Character(UnicodeScalar(text.character(at: i))!).isNumber ||
                       text.character(at: i) == UInt16(UnicodeScalar(".").value) ||
                       text.character(at: i) == UInt16(UnicodeScalar("e").value) ||
                       text.character(at: i) == UInt16(UnicodeScalar("E").value) ||
                       text.character(at: i) == UInt16(UnicodeScalar("+").value) ||
                       text.character(at: i) == UInt16(UnicodeScalar("-").value)) { i += 1 }
                if i > start + (ch == "-" ? 1 : 0) {
                    attr.addAttribute(.foregroundColor, value: T.jNum, range: NSRange(location: start, length: i - start)); continue
                }
            }
            if c == UInt16(UnicodeScalar("t").value) && i + 4 <= len && text.substring(with: NSRange(location: i, length: 4)) == "true" {
                attr.addAttribute(.foregroundColor, value: T.jBool, range: NSRange(location: i, length: 4)); i += 4; continue
            }
            if c == UInt16(UnicodeScalar("f").value) && i + 5 <= len && text.substring(with: NSRange(location: i, length: 5)) == "false" {
                attr.addAttribute(.foregroundColor, value: T.jBool, range: NSRange(location: i, length: 5)); i += 5; continue
            }
            if c == UInt16(UnicodeScalar("n").value) && i + 4 <= len && text.substring(with: NSRange(location: i, length: 4)) == "null" {
                attr.addAttribute(.foregroundColor, value: T.jNull, range: NSRange(location: i, length: 4)); i += 4; continue
            }
            if c == UInt16(UnicodeScalar("{").value) || c == UInt16(UnicodeScalar("}").value) ||
               c == UInt16(UnicodeScalar("[").value) || c == UInt16(UnicodeScalar("]").value) {
                attr.addAttribute(.foregroundColor, value: T.jBrk, range: NSRange(location: i, length: 1))
            }
            i += 1
        }
        return attr
    }

    func simplifyError(_ msg: String) -> String {
        if msg.contains("Unexpected character") || msg.contains("Invalid value") { return "JSON 格式错误: \(msg)" }
        if msg.contains("Unexpected end") || msg.contains("Badly formed") { return "JSON 未完整结束" }
        return msg
    }

    func showToast(_ msg: String) {
        guard let w = view.window else { return }
        let t = NSTextField(labelWithString: msg)
        t.font = NSFont.systemFont(ofSize: 13); t.textColor = .white
        t.isBezeled = false; t.wantsLayer = true; t.layer?.cornerRadius = 8
        t.layer?.backgroundColor = NSColor(calibratedRed: 0.1, green: 0.1, blue: 0.15, alpha: 0.9).cgColor
        t.alignment = .center; t.sizeToFit()
        let p: CGFloat = 20
        t.frame = NSRect(x: (w.contentView!.bounds.width - t.frame.width - p*2)/2, y: 40,
                          width: t.frame.width + p*2, height: 32)
        t.alphaValue = 0; w.contentView?.addSubview(t)
        NSAnimationContext.runAnimationGroup({ ctx in ctx.duration = 0.2; t.animator().alphaValue = 1 }) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                NSAnimationContext.runAnimationGroup({ ctx in ctx.duration = 0.3; t.animator().alphaValue = 0 }) { t.removeFromSuperview() }
            }
        }
    }
}

// MARK: - Timestamp Converter
class TimestampVC: NSViewController, NSTextFieldDelegate {
    var currentValueL: NSTextField!
    var currentDatetimeL: NSTextField!
    var tsUnit = "sec"
    var timer: Timer?
    var secBtn: NSButton!
    var msBtn: NSButton!
    var toDateRows: [(row: NSView, input: NSTextField, unitSel: NSPopUpButton, result: NSTextField, copyBtn: NSButton, lastResult: String)] = []
    var toDateStack: NSStackView!
    var toDateCard: NSView!
    var toDateBottomC: NSLayoutConstraint?
    var toStampInput: NSTextField!
    var toStampResult: NSTextField!
    var toStampCopyS: NSButton!
    var toStampCopyMs: NSButton!
    var lastToStampSec = ""
    var lastToStampMs = ""

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 1100, height: 650))
        view.wantsLayer = true; view.layer?.backgroundColor = T.bg.cgColor
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        startTimer()
    }

    func setupUI() {
        let scrollView = NSScrollView(); scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder; scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(scrollView)

        let container = FlippedView(); container.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = container

        // Status bar
        let statusBar = NSView(); statusBar.wantsLayer = true; statusBar.layer?.backgroundColor = T.bgCard.cgColor
        statusBar.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(statusBar)
        let sbLine = NSView(); sbLine.wantsLayer = true; sbLine.layer?.backgroundColor = T.brd.cgColor
        sbLine.translatesAutoresizingMaskIntoConstraints = false; statusBar.addSubview(sbLine)
        let sDot = NSView(); sDot.wantsLayer = true; sDot.layer?.cornerRadius = 3
        sDot.layer?.backgroundColor = T.green.cgColor; sDot.translatesAutoresizingMaskIntoConstraints = false; statusBar.addSubview(sDot)
        let sL = NSTextField(labelWithString: "时间戳工具就绪"); sL.font = NSFont.systemFont(ofSize: 11)
        sL.textColor = T.t3; sL.translatesAutoresizingMaskIntoConstraints = false; statusBar.addSubview(sL)
        let hL = NSTextField(labelWithString: "Tab 切换  ESC 关闭"); hL.font = NSFont.systemFont(ofSize: 11)
        hL.textColor = T.t3; hL.translatesAutoresizingMaskIntoConstraints = false; statusBar.addSubview(hL)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: statusBar.topAnchor),
            container.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            container.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            container.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
            statusBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            statusBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            statusBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            statusBar.heightAnchor.constraint(equalToConstant: 28),
            sbLine.topAnchor.constraint(equalTo: statusBar.topAnchor),
            sbLine.leadingAnchor.constraint(equalTo: statusBar.leadingAnchor),
            sbLine.trailingAnchor.constraint(equalTo: statusBar.trailingAnchor),
            sbLine.heightAnchor.constraint(equalToConstant: 1),
            sDot.leadingAnchor.constraint(equalTo: statusBar.leadingAnchor, constant: 16),
            sDot.centerYAnchor.constraint(equalTo: statusBar.centerYAnchor),
            sDot.widthAnchor.constraint(equalToConstant: 6), sDot.heightAnchor.constraint(equalToConstant: 6),
            sL.leadingAnchor.constraint(equalTo: sDot.trailingAnchor, constant: 6),
            sL.centerYAnchor.constraint(equalTo: statusBar.centerYAnchor),
            hL.trailingAnchor.constraint(equalTo: statusBar.trailingAnchor, constant: -16),
            hL.centerYAnchor.constraint(equalTo: statusBar.centerYAnchor),
        ])

        // Card 1: Current Timestamp
        let c1 = makeCard(); container.addSubview(c1)
        let c1T = makeCardTitle("⏱ 当前时间戳"); c1.addSubview(c1T)
        currentValueL = NSTextField(labelWithString: "0"); currentValueL.font = NSFont.monospacedSystemFont(ofSize: 32, weight: .bold)
        currentValueL.textColor = T.accent; currentValueL.translatesAutoresizingMaskIntoConstraints = false; c1.addSubview(currentValueL)
        secBtn = NSButton(title: "秒 (s)", target: self, action: #selector(setUnitSec))
        secBtn.wantsLayer = true; secBtn.translatesAutoresizingMaskIntoConstraints = false; c1.addSubview(secBtn)
        updateUnitBtn(secBtn, active: true)
        msBtn = NSButton(title: "毫秒 (ms)", target: self, action: #selector(setUnitMs))
        msBtn.wantsLayer = true; msBtn.translatesAutoresizingMaskIntoConstraints = false; c1.addSubview(msBtn)
        updateUnitBtn(msBtn, active: false)
        let copyBtn = NSButton(title: "📋 复制", target: self, action: #selector(copyCurrent))
        copyBtn.bezelStyle = .roundRect; copyBtn.font = NSFont.systemFont(ofSize: 12)
        copyBtn.translatesAutoresizingMaskIntoConstraints = false; c1.addSubview(copyBtn)
        currentDatetimeL = NSTextField(labelWithString: ""); currentDatetimeL.font = T.mono
        currentDatetimeL.textColor = T.t3; currentDatetimeL.translatesAutoresizingMaskIntoConstraints = false; c1.addSubview(currentDatetimeL)

        NSLayoutConstraint.activate([
            c1.topAnchor.constraint(equalTo: container.topAnchor, constant: 24),
            c1.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 24),
            c1.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -24),
            c1T.topAnchor.constraint(equalTo: c1.topAnchor, constant: 20),
            c1T.leadingAnchor.constraint(equalTo: c1.leadingAnchor, constant: 24),
            currentValueL.topAnchor.constraint(equalTo: c1T.bottomAnchor, constant: 16),
            currentValueL.leadingAnchor.constraint(equalTo: c1.leadingAnchor, constant: 24),
            secBtn.centerYAnchor.constraint(equalTo: currentValueL.centerYAnchor),
            secBtn.leadingAnchor.constraint(equalTo: currentValueL.trailingAnchor, constant: 16),
            secBtn.heightAnchor.constraint(equalToConstant: 28),
            msBtn.centerYAnchor.constraint(equalTo: currentValueL.centerYAnchor),
            msBtn.leadingAnchor.constraint(equalTo: secBtn.trailingAnchor, constant: 8),
            msBtn.heightAnchor.constraint(equalToConstant: 28),
            copyBtn.centerYAnchor.constraint(equalTo: currentValueL.centerYAnchor),
            copyBtn.leadingAnchor.constraint(equalTo: msBtn.trailingAnchor, constant: 8),
            copyBtn.heightAnchor.constraint(equalToConstant: 28),
            currentDatetimeL.topAnchor.constraint(equalTo: currentValueL.bottomAnchor, constant: 10),
            currentDatetimeL.leadingAnchor.constraint(equalTo: c1.leadingAnchor, constant: 24),
            currentDatetimeL.bottomAnchor.constraint(equalTo: c1.bottomAnchor, constant: -20),
        ])

        // Card 2: Timestamp → Date (dynamic multi-row)
        toDateCard = makeCard(); container.addSubview(toDateCard)
        let c2 = toDateCard!
        let c2T = makeCardTitle("🔄 时间戳 → 日期时间"); c2.addSubview(c2T)

        // "+" button next to title
        let addRowBtn = NSButton(title: "＋", target: self, action: #selector(addToDateRow))
        addRowBtn.wantsLayer = true; addRowBtn.isBordered = false
        addRowBtn.layer?.backgroundColor = T.accent.cgColor; addRowBtn.layer?.cornerRadius = 12
        addRowBtn.contentTintColor = .white; addRowBtn.font = NSFont.systemFont(ofSize: 14, weight: .bold)
        addRowBtn.translatesAutoresizingMaskIntoConstraints = false; c2.addSubview(addRowBtn)

        // Stack view for rows
        toDateStack = NSStackView(); toDateStack.orientation = .vertical
        toDateStack.spacing = 10; toDateStack.alignment = .leading
        toDateStack.translatesAutoresizingMaskIntoConstraints = false; c2.addSubview(toDateStack)

        NSLayoutConstraint.activate([
            c2.topAnchor.constraint(equalTo: c1.bottomAnchor, constant: 20),
            c2.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 24),
            c2.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -24),
            c2T.topAnchor.constraint(equalTo: c2.topAnchor, constant: 20),
            c2T.leadingAnchor.constraint(equalTo: c2.leadingAnchor, constant: 24),

            addRowBtn.centerYAnchor.constraint(equalTo: c2T.centerYAnchor),
            addRowBtn.leadingAnchor.constraint(equalTo: c2T.trailingAnchor, constant: 10),
            addRowBtn.widthAnchor.constraint(equalToConstant: 24),
            addRowBtn.heightAnchor.constraint(equalToConstant: 24),

            toDateStack.topAnchor.constraint(equalTo: c2T.bottomAnchor, constant: 16),
            toDateStack.leadingAnchor.constraint(equalTo: c2.leadingAnchor, constant: 24),
            toDateStack.trailingAnchor.constraint(equalTo: c2.trailingAnchor, constant: -24),
        ])
        toDateBottomC = toDateStack.bottomAnchor.constraint(equalTo: c2.bottomAnchor, constant: -20)
        toDateBottomC?.isActive = true

        // Add first row
        addToDateRow()

        // Card 3: Date → Timestamp (single-row layout)
        let c3 = makeCard(); container.addSubview(c3)
        let c3T = makeCardTitle("🔄 日期时间 → 时间戳"); c3.addSubview(c3T)

        // Input box
        let toStampInputBox = NSView(); toStampInputBox.wantsLayer = true
        toStampInputBox.layer?.backgroundColor = NSColor.white.cgColor
        toStampInputBox.layer?.cornerRadius = 8; toStampInputBox.layer?.borderWidth = 1
        toStampInputBox.layer?.borderColor = T.brd.cgColor; toStampInputBox.layer?.masksToBounds = true
        toStampInputBox.translatesAutoresizingMaskIntoConstraints = false; c3.addSubview(toStampInputBox)

        toStampInput = NSTextField(); toStampInput.placeholderString = "输入日期时间"
        toStampInput.font = T.mono; toStampInput.focusRingType = .none
        toStampInput.isBordered = false; toStampInput.drawsBackground = false
        toStampInput.isBezeled = false; toStampInput.backgroundColor = .clear
        toStampInput.translatesAutoresizingMaskIntoConstraints = false
        toStampInput.target = self; toStampInput.action = #selector(toStampConvert)
        toStampInput.delegate = self
        if let cell = toStampInput.cell as? NSTextFieldCell {
            cell.wraps = false; cell.isScrollable = true
            cell.usesSingleLineMode = true; cell.lineBreakMode = .byTruncatingTail
            cell.drawsBackground = false
        }
        toStampInputBox.addSubview(toStampInput)

        // Convert button
        let toStampBtn = NSButton(title: "转换", target: self, action: #selector(toStampConvert))
        toStampBtn.wantsLayer = true; toStampBtn.layer?.backgroundColor = T.accent.cgColor
        toStampBtn.layer?.cornerRadius = 8; toStampBtn.contentTintColor = .white
        toStampBtn.isBordered = false; toStampBtn.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        toStampBtn.translatesAutoresizingMaskIntoConstraints = false; c3.addSubview(toStampBtn)

        // Result label (inline)
        toStampResult = NSTextField(labelWithString: "转换结果"); toStampResult.font = T.mono
        toStampResult.textColor = T.t3; toStampResult.isSelectable = true
        toStampResult.alignment = .left; toStampResult.lineBreakMode = .byTruncatingTail
        toStampResult.translatesAutoresizingMaskIntoConstraints = false
        c3.addSubview(toStampResult)

        // Copy buttons
        toStampCopyS = NSButton(title: "复制(s)", target: self, action: #selector(copyStampSec))
        toStampCopyS.bezelStyle = .roundRect; toStampCopyS.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        toStampCopyS.translatesAutoresizingMaskIntoConstraints = false; toStampCopyS.isHidden = true; c3.addSubview(toStampCopyS)
        toStampCopyMs = NSButton(title: "复制(ms)", target: self, action: #selector(copyStampMs))
        toStampCopyMs.bezelStyle = .roundRect; toStampCopyMs.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        toStampCopyMs.translatesAutoresizingMaskIntoConstraints = false; toStampCopyMs.isHidden = true; c3.addSubview(toStampCopyMs)

        NSLayoutConstraint.activate([
            c3.topAnchor.constraint(equalTo: c2.bottomAnchor, constant: 20),
            c3.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 24),
            c3.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -24),
            c3.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -24),
            c3T.topAnchor.constraint(equalTo: c3.topAnchor, constant: 20),
            c3T.leadingAnchor.constraint(equalTo: c3.leadingAnchor, constant: 24),

            // Single row: [inputBox] [btn] [result...] [copyMs] [copyS]
            toStampInputBox.topAnchor.constraint(equalTo: c3T.bottomAnchor, constant: 16),
            toStampInputBox.leadingAnchor.constraint(equalTo: c3.leadingAnchor, constant: 24),
            toStampInputBox.widthAnchor.constraint(equalTo: c3.widthAnchor, multiplier: 0.35, constant: -24),
            toStampInputBox.heightAnchor.constraint(equalToConstant: 36),
            toStampInputBox.bottomAnchor.constraint(equalTo: c3.bottomAnchor, constant: -20),
            toStampInput.leadingAnchor.constraint(equalTo: toStampInputBox.leadingAnchor, constant: 10),
            toStampInput.trailingAnchor.constraint(equalTo: toStampInputBox.trailingAnchor, constant: -10),
            toStampInput.centerYAnchor.constraint(equalTo: toStampInputBox.centerYAnchor),

            toStampBtn.centerYAnchor.constraint(equalTo: toStampInputBox.centerYAnchor),
            toStampBtn.leadingAnchor.constraint(equalTo: toStampInputBox.trailingAnchor, constant: 8),
            toStampBtn.widthAnchor.constraint(equalToConstant: 56),
            toStampBtn.heightAnchor.constraint(equalToConstant: 32),

            toStampResult.centerYAnchor.constraint(equalTo: toStampInputBox.centerYAnchor),
            toStampResult.leadingAnchor.constraint(equalTo: toStampBtn.trailingAnchor, constant: 12),
            toStampResult.trailingAnchor.constraint(equalTo: toStampCopyMs.leadingAnchor, constant: -8),

            toStampCopyMs.centerYAnchor.constraint(equalTo: toStampInputBox.centerYAnchor),
            toStampCopyMs.trailingAnchor.constraint(equalTo: toStampCopyS.leadingAnchor, constant: -6),
            toStampCopyMs.widthAnchor.constraint(equalToConstant: 76),
            toStampCopyMs.heightAnchor.constraint(equalToConstant: 28),

            toStampCopyS.centerYAnchor.constraint(equalTo: toStampInputBox.centerYAnchor),
            toStampCopyS.trailingAnchor.constraint(equalTo: c3.trailingAnchor, constant: -24),
            toStampCopyS.widthAnchor.constraint(equalToConstant: 68),
            toStampCopyS.heightAnchor.constraint(equalToConstant: 28),
        ])
    }

    func makeCard() -> NSView {
        let c = NSView(); c.wantsLayer = true; c.layer?.backgroundColor = T.bgCard.cgColor
        c.layer?.cornerRadius = 12; c.layer?.borderWidth = 1; c.layer?.borderColor = T.brd.cgColor
        c.translatesAutoresizingMaskIntoConstraints = false; return c
    }
    func makeCardTitle(_ text: String) -> NSTextField {
        let l = NSTextField(labelWithString: text); l.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        l.textColor = T.t1; l.translatesAutoresizingMaskIntoConstraints = false; return l
    }
    func updateUnitBtn(_ btn: NSButton, active: Bool) {
        if active {
            btn.contentTintColor = .white; btn.layer?.backgroundColor = T.accent.cgColor
            btn.layer?.cornerRadius = 7; btn.isBordered = false
        } else {
            btn.contentTintColor = T.t2; btn.layer?.backgroundColor = NSColor.clear.cgColor
            btn.isBordered = true
        }
        btn.font = NSFont.systemFont(ofSize: 12, weight: .medium)
    }

    // MARK: - Timer
    func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in self?.updateCurrent() }
    }
    func updateCurrent() {
        let now = Date(); let ms = Int64(now.timeIntervalSince1970 * 1000); let sec = ms / 1000
        let display = tsUnit == "ms" ? ms : sec
        currentValueL?.stringValue = "\(display)"
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        currentDatetimeL?.stringValue = fmt.string(from: now)
    }

    // MARK: - Actions
    @objc func setUnitSec() { tsUnit = "sec"; updateUnitBtn(secBtn, active: true); updateUnitBtn(msBtn, active: false) }
    @objc func setUnitMs() { tsUnit = "ms"; updateUnitBtn(secBtn, active: false); updateUnitBtn(msBtn, active: true) }
    @objc func copyCurrent() {
        let v = currentValueL.stringValue
        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(v, forType: .string)
        showToast("✓ 已复制: \(v)")
    }

    func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSTextField else { return }
        if let idx = toDateRows.firstIndex(where: { $0.input === field }) { convertToDateAtRow(idx) }
        else if field === toStampInput { toStampConvert() }
    }

    @objc func addToDateRow() {
        let rowView = NSView(); rowView.translatesAutoresizingMaskIntoConstraints = false

        // Input box
        let inputBox = NSView(); inputBox.wantsLayer = true
        inputBox.layer?.backgroundColor = NSColor.white.cgColor
        inputBox.layer?.cornerRadius = 8; inputBox.layer?.borderWidth = 1
        inputBox.layer?.borderColor = T.brd.cgColor; inputBox.layer?.masksToBounds = true
        inputBox.translatesAutoresizingMaskIntoConstraints = false; rowView.addSubview(inputBox)

        let input = NSTextField(); input.placeholderString = "输入时间戳"
        input.font = T.mono; input.focusRingType = .none
        input.isBordered = false; input.drawsBackground = false
        input.isBezeled = false; input.backgroundColor = .clear
        input.translatesAutoresizingMaskIntoConstraints = false
        input.target = self; input.action = #selector(toDateConvertRow(_:))
        input.delegate = self
        if let cell = input.cell as? NSTextFieldCell {
            cell.wraps = false; cell.isScrollable = true
            cell.usesSingleLineMode = true; cell.lineBreakMode = .byTruncatingTail
            cell.drawsBackground = false
        }
        inputBox.addSubview(input)

        // Unit selector
        let unitSel = NSPopUpButton()
        unitSel.addItem(withTitle: "自动"); unitSel.addItem(withTitle: "秒"); unitSel.addItem(withTitle: "毫秒")
        unitSel.selectItem(at: 0); unitSel.font = NSFont.systemFont(ofSize: 13)
        unitSel.translatesAutoresizingMaskIntoConstraints = false
        unitSel.setContentHuggingPriority(.required, for: .horizontal)
        rowView.addSubview(unitSel)

        // Convert button
        let cvtBtn = NSButton(title: "转换", target: self, action: #selector(toDateConvertBtn(_:)))
        cvtBtn.wantsLayer = true; cvtBtn.layer?.backgroundColor = T.accent.cgColor
        cvtBtn.layer?.cornerRadius = 8; cvtBtn.contentTintColor = .white
        cvtBtn.isBordered = false; cvtBtn.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        cvtBtn.translatesAutoresizingMaskIntoConstraints = false; rowView.addSubview(cvtBtn)

        // Result label
        let result = NSTextField(labelWithString: "转换结果"); result.font = T.mono
        result.textColor = T.t3; result.isSelectable = true
        result.alignment = .left; result.lineBreakMode = .byTruncatingTail
        result.translatesAutoresizingMaskIntoConstraints = false; rowView.addSubview(result)

        // Copy button
        let copyBtn = NSButton(title: "复制", target: self, action: #selector(copyToDateRow(_:)))
        copyBtn.bezelStyle = .roundRect; copyBtn.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        copyBtn.translatesAutoresizingMaskIntoConstraints = false; copyBtn.isHidden = true; rowView.addSubview(copyBtn)

        // Delete button (shown for rows after the first)
        let delBtn = NSButton(title: "✕", target: self, action: #selector(removeToDateRow(_:)))
        delBtn.wantsLayer = true; delBtn.isBordered = false
        delBtn.layer?.cornerRadius = 10; delBtn.contentTintColor = T.red
        delBtn.font = NSFont.systemFont(ofSize: 12, weight: .bold)
        delBtn.translatesAutoresizingMaskIntoConstraints = false
        delBtn.isHidden = toDateRows.isEmpty // hide for first row
        rowView.addSubview(delBtn)

        NSLayoutConstraint.activate([
            rowView.heightAnchor.constraint(equalToConstant: 36),

            inputBox.leadingAnchor.constraint(equalTo: rowView.leadingAnchor),
            inputBox.centerYAnchor.constraint(equalTo: rowView.centerYAnchor),
            inputBox.widthAnchor.constraint(equalTo: rowView.widthAnchor, multiplier: 0.26),
            inputBox.heightAnchor.constraint(equalToConstant: 36),
            input.leadingAnchor.constraint(equalTo: inputBox.leadingAnchor, constant: 10),
            input.trailingAnchor.constraint(equalTo: inputBox.trailingAnchor, constant: -10),
            input.centerYAnchor.constraint(equalTo: inputBox.centerYAnchor),

            unitSel.centerYAnchor.constraint(equalTo: rowView.centerYAnchor),
            unitSel.leadingAnchor.constraint(equalTo: inputBox.trailingAnchor, constant: 8),
            unitSel.widthAnchor.constraint(equalToConstant: 72),

            cvtBtn.centerYAnchor.constraint(equalTo: rowView.centerYAnchor),
            cvtBtn.leadingAnchor.constraint(equalTo: unitSel.trailingAnchor, constant: 8),
            cvtBtn.widthAnchor.constraint(equalToConstant: 56),
            cvtBtn.heightAnchor.constraint(equalToConstant: 32),

            result.centerYAnchor.constraint(equalTo: rowView.centerYAnchor),
            result.leadingAnchor.constraint(equalTo: cvtBtn.trailingAnchor, constant: 12),
            result.trailingAnchor.constraint(equalTo: copyBtn.leadingAnchor, constant: -6),

            copyBtn.centerYAnchor.constraint(equalTo: rowView.centerYAnchor),
            copyBtn.trailingAnchor.constraint(equalTo: delBtn.leadingAnchor, constant: -4),
            copyBtn.widthAnchor.constraint(equalToConstant: 48),
            copyBtn.heightAnchor.constraint(equalToConstant: 28),

            delBtn.centerYAnchor.constraint(equalTo: rowView.centerYAnchor),
            delBtn.trailingAnchor.constraint(equalTo: rowView.trailingAnchor),
            delBtn.widthAnchor.constraint(equalToConstant: 24),
            delBtn.heightAnchor.constraint(equalToConstant: 24),
        ])

        toDateStack.addArrangedSubview(rowView)
        rowView.widthAnchor.constraint(equalTo: toDateStack.widthAnchor).isActive = true
        toDateRows.append((row: rowView, input: input, unitSel: unitSel, result: result, copyBtn: copyBtn, lastResult: ""))
    }

    func findToDateRowIndex(from view: NSView) -> Int? {
        // Walk up from the sender to find which rowView it belongs to
        var v: NSView? = view
        while let current = v {
            if let idx = toDateRows.firstIndex(where: { $0.row === current }) { return idx }
            v = current.superview
        }
        return nil
    }

    @objc func toDateConvertRow(_ sender: NSTextField) {
        guard let idx = findToDateRowIndex(from: sender) else { return }
        convertToDateAtRow(idx)
    }

    @objc func toDateConvertBtn(_ sender: NSButton) {
        guard let idx = findToDateRowIndex(from: sender) else { return }
        convertToDateAtRow(idx)
    }

    func convertToDateAtRow(_ idx: Int) {
        guard idx < toDateRows.count else { return }
        let row = toDateRows[idx]
        let input = row.input.stringValue.trimmingCharacters(in: .whitespaces)
        if input.isEmpty { row.result.stringValue = "请输入时间戳"; row.result.textColor = T.t3; row.copyBtn.isHidden = true; return }
        guard let num = Double(input) else { row.result.stringValue = "无效的时间戳"; row.result.textColor = T.red; row.copyBtn.isHidden = true; return }

        let unitSel = row.unitSel.indexOfSelectedItem
        var ms: Double
        if unitSel == 0 { ms = num > 1e12 ? num : num * 1000 } // auto
        else if unitSel == 2 { ms = num } // ms
        else { ms = num * 1000 } // sec

        let date = Date(timeIntervalSince1970: ms / 1000)
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let result = fmt.string(from: date)
        toDateRows[idx].lastResult = result
        row.result.stringValue = result; row.result.textColor = T.t1
        row.copyBtn.isHidden = false
    }

    @objc func copyToDateRow(_ sender: NSButton) {
        guard let idx = findToDateRowIndex(from: sender) else { return }
        let result = toDateRows[idx].lastResult
        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(result, forType: .string)
        showToast("✓ 已复制: \(result)")
    }

    @objc func removeToDateRow(_ sender: NSButton) {
        guard let idx = findToDateRowIndex(from: sender), toDateRows.count > 1 else { return }
        let rowView = toDateRows[idx].row
        toDateStack.removeArrangedSubview(rowView); rowView.removeFromSuperview()
        toDateRows.remove(at: idx)
    }

    @objc func toStampConvert() {
        let input = toStampInput.stringValue.trimmingCharacters(in: .whitespaces)
        if input.isEmpty { toStampResult.stringValue = "请输入日期时间"; toStampResult.textColor = T.t3; toStampCopyS.isHidden = true; toStampCopyMs.isHidden = true; return }

        let formats = ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ss", "yyyy/MM/dd HH:mm:ss", "yyyy-MM-dd", "yyyy/MM/dd"]
        var date: Date? = nil; let fmt = DateFormatter(); fmt.locale = Locale(identifier: "en_US_POSIX")
        for f in formats { fmt.dateFormat = f; if let d = fmt.date(from: input) { date = d; break } }

        guard let d = date else {
            toStampResult.stringValue = "无法解析，请使用 yyyy-MM-dd HH:mm:ss"
            toStampResult.textColor = T.red; toStampCopyS.isHidden = true; toStampCopyMs.isHidden = true; return
        }

        let sec = Int64(d.timeIntervalSince1970)
        let ms = Int64(d.timeIntervalSince1970 * 1000)
        lastToStampSec = "\(sec)"; lastToStampMs = "\(ms)"
        toStampResult.stringValue = "\(sec) (秒) / \(ms) (毫秒)"
        toStampResult.textColor = T.t1; toStampCopyS.isHidden = false; toStampCopyMs.isHidden = false
    }

    @objc func copyStampSec() {
        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(lastToStampSec, forType: .string)
        showToast("✓ 已复制秒级时间戳")
    }
    @objc func copyStampMs() {
        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(lastToStampMs, forType: .string)
        showToast("✓ 已复制毫秒时间戳")
    }

    func showToast(_ msg: String) {
        guard let w = view.window else { return }
        let t = NSTextField(labelWithString: msg); t.font = NSFont.systemFont(ofSize: 13); t.textColor = .white
        t.isBezeled = false; t.wantsLayer = true; t.layer?.cornerRadius = 8
        t.layer?.backgroundColor = NSColor(calibratedRed: 0.1, green: 0.1, blue: 0.15, alpha: 0.9).cgColor
        t.alignment = .center; t.sizeToFit()
        let p: CGFloat = 20
        t.frame = NSRect(x: (w.contentView!.bounds.width - t.frame.width - p*2)/2, y: 40,
                          width: t.frame.width + p*2, height: 32)
        t.alphaValue = 0; w.contentView?.addSubview(t)
        NSAnimationContext.runAnimationGroup({ ctx in ctx.duration = 0.2; t.animator().alphaValue = 1 }) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                NSAnimationContext.runAnimationGroup({ ctx in ctx.duration = 0.3; t.animator().alphaValue = 0 }) { t.removeFromSuperview() }
            }
        }
    }

    deinit { timer?.invalidate() }
}

// (PaddedTextField removed - using standard NSTextField)

// MARK: - Custom NSTextView that forwards key equivalents
class CustomTextView: NSTextView {
    var onKeyEquivalent: ((NSEvent) -> Bool)?
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if let handler = onKeyEquivalent, handler(event) { return true }
        return super.performKeyEquivalent(with: event)
    }
}

// MARK: - Flipped View
class FlippedView: NSView { override var isFlipped: Bool { true } }

// MARK: - Main Entry
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
