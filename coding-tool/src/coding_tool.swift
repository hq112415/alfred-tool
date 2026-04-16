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
        else { view.window?.makeFirstResponder(tsVC.toDateInput) }
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
    var searchIdx = -1
    var searchHighlightColor = NSColor(calibratedRed: 0.996, green: 0.941, blue: 0.424, alpha: 1)
    var searchCurrentColor = NSColor(calibratedRed: 0.984, green: 0.573, blue: 0.235, alpha: 1)
    var formatDebounceTimer: Timer?

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
            ("📄 复制", #selector(copyOutput)),
            ("✨ 格式化", #selector(formatJSON)),
            ("📦 删除空格", #selector(minifyJSON)),
            ("🔒 删除空格并转义", #selector(minifyAndEscape)),
            ("🔓 去除转义", #selector(unescapeJSON)),
        ]
        let rightBtns: [(String, Selector)] = [
            ("📋 示例", #selector(loadSample)),
            ("🗑 清空", #selector(clearAll)),
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
        gutterTV.isRichText = false; gutterTV.font = T.monoSm; gutterTV.textColor = T.t3
        gutterTV.backgroundColor = T.bg; gutterTV.textContainerInset = NSSize(width: 8, height: 14)
        gutterTV.isAutomaticQuoteSubstitutionEnabled = false
        gutterTV.minSize = NSSize(width: 0, height: 0)
        gutterTV.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        gutterTV.isVerticallyResizable = true; gutterTV.isHorizontallyResizable = false
        gutterTV.autoresizingMask = [.width]
        gutterTV.textContainer?.widthTracksTextView = true
        gutterTV.textContainer?.containerSize = NSSize(width: 44, height: CGFloat.greatestFiniteMagnitude)
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
            gutterScroll.widthAnchor.constraint(equalToConstant: 44),
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
            let formatted = prettyPrint(parsed, indent: indentStr)
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
            let formatted = prettyPrint(parsed, indent: indentStr)
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
            let formatted = prettyPrint(parsed, indent: indentStr)
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
            let formatted = prettyPrint(parsed, indent: indentStr)
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
        let attr = highlight(json)
        outputTV.textStorage?.setAttributedString(attr)
        let lines = json.components(separatedBy: "\n")
        outputSizeL.stringValue = "\(lines.count) lines"
        updateGutter(lines.count)
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
            let minData = try JSONSerialization.data(withJSONObject: parsed, options: [.sortedKeys, .fragmentsAllowed])
            let minified = String(data: minData, encoding: .utf8) ?? ""
            lastFormatted = minified; lastParsed = parsed; isValid = true
            displayOutput(minified)
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
            let minData = try JSONSerialization.data(withJSONObject: parsed, options: [.sortedKeys, .fragmentsAllowed])
            let minified = String(data: minData, encoding: .utf8) ?? ""
            guard let escData = try? JSONSerialization.data(withJSONObject: minified, options: [.fragmentsAllowed]) else { return }
            var escaped = String(data: escData, encoding: .utf8) ?? ""
            if escaped.hasPrefix("\"") && escaped.hasSuffix("\"") { escaped = String(escaped.dropFirst().dropLast()) }
            lastFormatted = escaped; lastParsed = parsed; isValid = true
            let attr = NSMutableAttributedString(string: escaped, attributes: [.font: T.mono, .foregroundColor: T.t1])
            outputTV.textStorage?.setAttributedString(attr)
            outputSizeL.stringValue = "1 lines"; updateGutter(1)
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

    @objc func expandAll() { showToast("全部展开") }
    @objc func collapseAll() { showToast("全部折叠") }

    // MARK: - Search
    @objc func openSearch() {
        searchBar.isHidden = false
        view.window?.makeFirstResponder(searchField)
    }
    @objc func closeSearch() {
        searchBar.isHidden = true
        searchMatches = []; searchIdx = -1; searchInfoL.stringValue = ""
        clearSearchHighlights()
    }
    @objc func performSearch() {
        clearSearchHighlights()
        let q = searchField.stringValue.trimmingCharacters(in: .whitespaces)
        if q.isEmpty { searchMatches = []; searchIdx = -1; searchInfoL.stringValue = ""; return }
        let text = outputTV.string as NSString
        let qLower = q.lowercased()
        let textLower = text.lowercased as NSString
        searchMatches = []; var pos = 0
        while true {
            let found = textLower.range(of: qLower, options: [], range: NSRange(location: pos, length: textLower.length - pos))
            if found.location == NSNotFound { break }
            searchMatches.append(found); pos = found.location + found.length
        }
        if searchMatches.isEmpty {
            searchIdx = -1; searchInfoL.stringValue = "无结果"
        } else {
            searchIdx = 0; highlightSearchMatches(); searchInfoL.stringValue = "1 / \(searchMatches.count)"
            scrollToSearchMatch(0)
        }
    }
    @objc func searchNext() {
        if searchMatches.isEmpty { return }
        searchIdx = (searchIdx + 1) % searchMatches.count
        highlightSearchMatches(); searchInfoL.stringValue = "\(searchIdx+1) / \(searchMatches.count)"
        scrollToSearchMatch(searchIdx)
    }
    @objc func searchPrev() {
        if searchMatches.isEmpty { return }
        searchIdx = (searchIdx - 1 + searchMatches.count) % searchMatches.count
        highlightSearchMatches(); searchInfoL.stringValue = "\(searchIdx+1) / \(searchMatches.count)"
        scrollToSearchMatch(searchIdx)
    }
    func highlightSearchMatches() {
        let storage = outputTV.textStorage ?? NSTextStorage()
        // Reset to base colors
        let text = outputTV.string
        storage.setAttributedString(highlight(text))
        for (i, r) in searchMatches.enumerated() {
            storage.addAttribute(.backgroundColor, value: i == searchIdx ? searchCurrentColor : searchHighlightColor, range: r)
        }
    }
    func clearSearchHighlights() {
        let text = outputTV.string
        if !text.isEmpty { outputTV.textStorage?.setAttributedString(highlight(text)) }
    }
    func scrollToSearchMatch(_ idx: Int) {
        guard idx >= 0 && idx < searchMatches.count else { return }
        let r = searchMatches[idx]
        outputTV.scrollRangeToVisible(r)
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
    func prettyPrint(_ value: Any, indent: String) -> String {
        return renderVal(value, depth: 0, indent: indent)
    }
    func renderVal(_ value: Any, depth: Int, indent: String) -> String {
        let prefix = String(repeating: indent, count: depth)
        let child = String(repeating: indent, count: depth + 1)
        if value is NSNull { return "null" }
        if let b = value as? Bool { return b ? "true" : "false" }
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
                lines.append("\(child)\(renderVal(item, depth: depth + 1, indent: indent))\(comma)")
            }
            lines.append("\(prefix)]"); return lines.joined(separator: "\n")
        }
        if let dict = value as? [String: Any] {
            if dict.isEmpty { return "{}" }
            let keys = dict.keys.sorted()
            var lines = ["{"]
            for (i, key) in keys.enumerated() {
                let comma = i < keys.count - 1 ? "," : ""
                let val = dict[key]!
                let rendered = renderVal(val, depth: depth + 1, indent: indent)
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
    var toDateInput: NSTextField!
    var toDateResult: NSTextField!
    var toStampInput: NSTextField!
    var toStampResult: NSTextField!
    var toDateCopyBtn: NSButton!
    var toStampCopyS: NSButton!
    var toStampCopyMs: NSButton!
    var toDateUnitSel: NSPopUpButton!
    var lastToDateResult = ""
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

        // Card 2: Timestamp → Date (two-row layout)
        let c2 = makeCard(); container.addSubview(c2)
        let c2T = makeCardTitle("🔄 时间戳 → 日期时间"); c2.addSubview(c2T)

        // Row 1: input box (NSView bg) + unit selector + convert button
        let toDateInputBox = NSView(); toDateInputBox.wantsLayer = true
        toDateInputBox.layer?.backgroundColor = NSColor.white.cgColor
        toDateInputBox.layer?.cornerRadius = 8; toDateInputBox.layer?.borderWidth = 1
        toDateInputBox.layer?.borderColor = T.brd.cgColor; toDateInputBox.layer?.masksToBounds = true
        toDateInputBox.translatesAutoresizingMaskIntoConstraints = false; c2.addSubview(toDateInputBox)

        toDateInput = NSTextField(); toDateInput.placeholderString = "输入时间戳"
        toDateInput.font = T.mono; toDateInput.focusRingType = .none
        toDateInput.isBordered = false; toDateInput.drawsBackground = false
        toDateInput.isBezeled = false; toDateInput.backgroundColor = .clear
        toDateInput.translatesAutoresizingMaskIntoConstraints = false
        toDateInput.target = self; toDateInput.action = #selector(toDateConvert)
        if let cell = toDateInput.cell as? NSTextFieldCell {
            cell.wraps = false; cell.isScrollable = true
            cell.usesSingleLineMode = true; cell.lineBreakMode = .byTruncatingTail
            cell.drawsBackground = false
        }
        toDateInputBox.addSubview(toDateInput)

        toDateUnitSel = NSPopUpButton()
        toDateUnitSel.addItem(withTitle: "自动"); toDateUnitSel.addItem(withTitle: "秒"); toDateUnitSel.addItem(withTitle: "毫秒")
        toDateUnitSel.selectItem(at: 0); toDateUnitSel.font = NSFont.systemFont(ofSize: 13)
        toDateUnitSel.translatesAutoresizingMaskIntoConstraints = false
        toDateUnitSel.setContentHuggingPriority(.required, for: .horizontal)
        c2.addSubview(toDateUnitSel)

        let toDateBtn = NSButton(title: "转换", target: self, action: #selector(toDateConvert))
        toDateBtn.wantsLayer = true; toDateBtn.layer?.backgroundColor = T.accent.cgColor
        toDateBtn.layer?.cornerRadius = 8; toDateBtn.contentTintColor = .white
        toDateBtn.isBordered = false; toDateBtn.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        toDateBtn.translatesAutoresizingMaskIntoConstraints = false; c2.addSubview(toDateBtn)

        // Row 2: result box (NSView bg) + copy button
        let toDateResultBox = NSView(); toDateResultBox.wantsLayer = true
        toDateResultBox.layer?.backgroundColor = T.bgInput.cgColor
        toDateResultBox.layer?.cornerRadius = 8; toDateResultBox.layer?.borderWidth = 1
        toDateResultBox.layer?.borderColor = T.brd.cgColor; toDateResultBox.layer?.masksToBounds = true
        toDateResultBox.translatesAutoresizingMaskIntoConstraints = false; c2.addSubview(toDateResultBox)

        toDateResult = NSTextField(labelWithString: "转换结果"); toDateResult.font = T.mono
        toDateResult.textColor = T.t3; toDateResult.isSelectable = true
        toDateResult.alignment = .left; toDateResult.lineBreakMode = .byTruncatingTail
        toDateResult.translatesAutoresizingMaskIntoConstraints = false
        toDateResultBox.addSubview(toDateResult)

        toDateCopyBtn = NSButton(title: "复制", target: self, action: #selector(copyToDateResult))
        toDateCopyBtn.bezelStyle = .roundRect; toDateCopyBtn.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        toDateCopyBtn.translatesAutoresizingMaskIntoConstraints = false; toDateCopyBtn.isHidden = true; c2.addSubview(toDateCopyBtn)

        NSLayoutConstraint.activate([
            c2.topAnchor.constraint(equalTo: c1.bottomAnchor, constant: 20),
            c2.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 24),
            c2.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -24),
            c2T.topAnchor.constraint(equalTo: c2.topAnchor, constant: 20),
            c2T.leadingAnchor.constraint(equalTo: c2.leadingAnchor, constant: 24),

            // Row 1: input(55%) + gap + unit(80) + gap + btn(72) + padding
            toDateInputBox.topAnchor.constraint(equalTo: c2T.bottomAnchor, constant: 16),
            toDateInputBox.leadingAnchor.constraint(equalTo: c2.leadingAnchor, constant: 24),
            toDateInputBox.widthAnchor.constraint(equalTo: c2.widthAnchor, multiplier: 0.55, constant: -24),
            toDateInputBox.heightAnchor.constraint(equalToConstant: 36),
            toDateInput.leadingAnchor.constraint(equalTo: toDateInputBox.leadingAnchor, constant: 10),
            toDateInput.trailingAnchor.constraint(equalTo: toDateInputBox.trailingAnchor, constant: -10),
            toDateInput.centerYAnchor.constraint(equalTo: toDateInputBox.centerYAnchor),

            toDateUnitSel.centerYAnchor.constraint(equalTo: toDateInputBox.centerYAnchor),
            toDateUnitSel.leadingAnchor.constraint(equalTo: toDateInputBox.trailingAnchor, constant: 12),
            toDateUnitSel.widthAnchor.constraint(equalToConstant: 80),

            toDateBtn.centerYAnchor.constraint(equalTo: toDateInputBox.centerYAnchor),
            toDateBtn.trailingAnchor.constraint(equalTo: c2.trailingAnchor, constant: -24),
            toDateBtn.widthAnchor.constraint(equalToConstant: 72),
            toDateBtn.heightAnchor.constraint(equalToConstant: 32),

            // Row 2: result box full width + copy btn
            toDateResultBox.topAnchor.constraint(equalTo: toDateInputBox.bottomAnchor, constant: 12),
            toDateResultBox.leadingAnchor.constraint(equalTo: c2.leadingAnchor, constant: 24),
            toDateResultBox.trailingAnchor.constraint(equalTo: c2.trailingAnchor, constant: -24),
            toDateResultBox.heightAnchor.constraint(equalToConstant: 36),
            toDateResultBox.bottomAnchor.constraint(equalTo: c2.bottomAnchor, constant: -20),
            toDateResult.leadingAnchor.constraint(equalTo: toDateResultBox.leadingAnchor, constant: 10),
            toDateResult.trailingAnchor.constraint(equalTo: toDateResultBox.trailingAnchor, constant: -10),
            toDateResult.centerYAnchor.constraint(equalTo: toDateResultBox.centerYAnchor),

            toDateCopyBtn.centerYAnchor.constraint(equalTo: toDateResultBox.centerYAnchor),
            toDateCopyBtn.trailingAnchor.constraint(equalTo: toDateResultBox.trailingAnchor, constant: -8),
            toDateCopyBtn.widthAnchor.constraint(equalToConstant: 56),
            toDateCopyBtn.heightAnchor.constraint(equalToConstant: 28),
        ])

        // Card 3: Date → Timestamp (two-row layout)
        let c3 = makeCard(); container.addSubview(c3)
        let c3T = makeCardTitle("🔄 日期时间 → 时间戳"); c3.addSubview(c3T)

        // Row 1: input box (NSView bg) + convert button
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

        let toStampBtn = NSButton(title: "转换", target: self, action: #selector(toStampConvert))
        toStampBtn.wantsLayer = true; toStampBtn.layer?.backgroundColor = T.accent.cgColor
        toStampBtn.layer?.cornerRadius = 8; toStampBtn.contentTintColor = .white
        toStampBtn.isBordered = false; toStampBtn.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        toStampBtn.translatesAutoresizingMaskIntoConstraints = false; c3.addSubview(toStampBtn)

        // Row 2: result box (NSView bg) + copy buttons
        let toStampResultBox = NSView(); toStampResultBox.wantsLayer = true
        toStampResultBox.layer?.backgroundColor = T.bgInput.cgColor
        toStampResultBox.layer?.cornerRadius = 8; toStampResultBox.layer?.borderWidth = 1
        toStampResultBox.layer?.borderColor = T.brd.cgColor; toStampResultBox.layer?.masksToBounds = true
        toStampResultBox.translatesAutoresizingMaskIntoConstraints = false; c3.addSubview(toStampResultBox)

        toStampResult = NSTextField(labelWithString: "转换结果"); toStampResult.font = T.mono
        toStampResult.textColor = T.t3; toStampResult.isSelectable = true
        toStampResult.alignment = .left; toStampResult.lineBreakMode = .byTruncatingTail
        toStampResult.translatesAutoresizingMaskIntoConstraints = false
        toStampResultBox.addSubview(toStampResult)

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

            // Row 1: input(55%) + gap + btn(72) + padding
            toStampInputBox.topAnchor.constraint(equalTo: c3T.bottomAnchor, constant: 16),
            toStampInputBox.leadingAnchor.constraint(equalTo: c3.leadingAnchor, constant: 24),
            toStampInputBox.widthAnchor.constraint(equalTo: c3.widthAnchor, multiplier: 0.55, constant: -24),
            toStampInputBox.heightAnchor.constraint(equalToConstant: 36),
            toStampInput.leadingAnchor.constraint(equalTo: toStampInputBox.leadingAnchor, constant: 10),
            toStampInput.trailingAnchor.constraint(equalTo: toStampInputBox.trailingAnchor, constant: -10),
            toStampInput.centerYAnchor.constraint(equalTo: toStampInputBox.centerYAnchor),

            toStampBtn.centerYAnchor.constraint(equalTo: toStampInputBox.centerYAnchor),
            toStampBtn.trailingAnchor.constraint(equalTo: c3.trailingAnchor, constant: -24),
            toStampBtn.widthAnchor.constraint(equalToConstant: 72),
            toStampBtn.heightAnchor.constraint(equalToConstant: 32),

            // Row 2: result box full width + copy btns inside
            toStampResultBox.topAnchor.constraint(equalTo: toStampInputBox.bottomAnchor, constant: 12),
            toStampResultBox.leadingAnchor.constraint(equalTo: c3.leadingAnchor, constant: 24),
            toStampResultBox.trailingAnchor.constraint(equalTo: c3.trailingAnchor, constant: -24),
            toStampResultBox.heightAnchor.constraint(equalToConstant: 36),
            toStampResultBox.bottomAnchor.constraint(equalTo: c3.bottomAnchor, constant: -20),
            toStampResult.leadingAnchor.constraint(equalTo: toStampResultBox.leadingAnchor, constant: 10),
            toStampResult.trailingAnchor.constraint(equalTo: toStampResultBox.trailingAnchor, constant: -10),
            toStampResult.centerYAnchor.constraint(equalTo: toStampResultBox.centerYAnchor),

            toStampCopyS.centerYAnchor.constraint(equalTo: toStampResultBox.centerYAnchor),
            toStampCopyS.trailingAnchor.constraint(equalTo: toStampResultBox.trailingAnchor, constant: -8),
            toStampCopyS.widthAnchor.constraint(equalToConstant: 68),
            toStampCopyS.heightAnchor.constraint(equalToConstant: 28),

            toStampCopyMs.centerYAnchor.constraint(equalTo: toStampResultBox.centerYAnchor),
            toStampCopyMs.trailingAnchor.constraint(equalTo: toStampCopyS.leadingAnchor, constant: -6),
            toStampCopyMs.widthAnchor.constraint(equalToConstant: 76),
            toStampCopyMs.heightAnchor.constraint(equalToConstant: 28),
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
        if field === toDateInput { toDateConvert() }
        else if field === toStampInput { toStampConvert() }
    }

    @objc func toDateConvert() {
        let input = toDateInput.stringValue.trimmingCharacters(in: .whitespaces)
        if input.isEmpty { toDateResult.stringValue = "请输入时间戳"; toDateResult.textColor = T.t3; toDateCopyBtn.isHidden = true; return }
        guard let num = Double(input) else { toDateResult.stringValue = "无效的时间戳"; toDateResult.textColor = T.red; toDateCopyBtn.isHidden = true; return }

        let unitSel = toDateUnitSel.indexOfSelectedItem
        var ms: Double
        if unitSel == 0 { ms = num > 1e12 ? num : num * 1000 } // auto
        else if unitSel == 2 { ms = num } // ms
        else { ms = num * 1000 } // sec

        let date = Date(timeIntervalSince1970: ms / 1000)
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let result = fmt.string(from: date)
        lastToDateResult = result
        toDateResult.stringValue = result; toDateResult.textColor = T.t1
        toDateCopyBtn.isHidden = false
    }

    @objc func copyToDateResult() {
        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(lastToDateResult, forType: .string)
        showToast("✓ 已复制: \(lastToDateResult)")
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
