import Cocoa
import Carbon

// MARK: - Constants
let pidFile = "/tmp/clipboard_manager_\(getuid()).pid"
let dataDir = NSHomeDirectory() + "/.clipboard_manager"
let dataFile = dataDir + "/data.json"
let configFile = dataDir + "/config.json"
let maxHistoryCount = 1000

// MARK: - Color Theme
struct Theme {
    static let bgBase = NSColor.white
    static let bgSurface = NSColor(calibratedRed: 0.96, green: 0.96, blue: 0.97, alpha: 1)
    static let bgOverlay = NSColor(calibratedRed: 0.93, green: 0.93, blue: 0.94, alpha: 1)
    static let bgHover = NSColor(calibratedRed: 0.94, green: 0.94, blue: 0.95, alpha: 1)
    static let bgSelected = NSColor(calibratedRed: 0.91, green: 0.93, blue: 0.98, alpha: 1)
    static let textPrimary = NSColor(calibratedRed: 0.114, green: 0.114, blue: 0.122, alpha: 1)
    static let textSecondary = NSColor(calibratedRed: 0.43, green: 0.43, blue: 0.45, alpha: 1)
    static let textMuted = NSColor(calibratedRed: 0.68, green: 0.68, blue: 0.70, alpha: 1)
    static let accent = NSColor(calibratedRed: 0, green: 0.478, blue: 1, alpha: 1)
    static let accentDim = NSColor(calibratedRed: 0, green: 0.478, blue: 1, alpha: 0.1)
    static let yellow = NSColor(calibratedRed: 1, green: 0.624, blue: 0.039, alpha: 1)
    static let red = NSColor(calibratedRed: 1, green: 0.231, blue: 0.188, alpha: 1)
    static let green = NSColor(calibratedRed: 0.204, green: 0.78, blue: 0.349, alpha: 1)
    static let greenDim = NSColor(calibratedRed: 0.204, green: 0.78, blue: 0.349, alpha: 0.1)
    static let border = NSColor(calibratedRed: 0.898, green: 0.898, blue: 0.918, alpha: 1)
    static let borderLight = NSColor(calibratedRed: 0.82, green: 0.82, blue: 0.84, alpha: 1)
}

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
        try? FileManager.default.createDirectory(atPath: dataDir, withIntermediateDirectories: true)
        if let jsonData = try? Data(contentsOf: URL(fileURLWithPath: dataFile)),
           let decoded = try? JSONDecoder().decode(ClipboardData.self, from: jsonData) {
            self.data = decoded
        } else {
            self.data = ClipboardData()
        }
        deduplicateItems()
    }

    private func deduplicateItems() {
        var seen: [String: Int] = [:]
        var deduped: [ClipboardItem] = []
        var changed = false

        for item in data.items {
            let key = item.content.trimmingCharacters(in: .whitespacesAndNewlines)
            if let existingIdx = seen[key] {
                if item.favorite && !deduped[existingIdx].favorite {
                    deduped[existingIdx].favorite = true
                }
                changed = true
            } else {
                seen[key] = deduped.count
                deduped.append(item)
            }
        }

        if changed {
            data.items = deduped
            save()
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

        data.items.removeAll { $0.content == trimmed && !$0.favorite }

        for i in 0..<data.items.count {
            if data.items[i].content == trimmed && data.items[i].favorite {
                data.items[i].timestamp = Date().timeIntervalSince1970
            }
        }

        let item = ClipboardItem(content: trimmed)
        data.items.insert(item, at: 0)

        let favorites = data.items.filter { $0.favorite }
        var nonFavorites = data.items.filter { !$0.favorite }
        if nonFavorites.count > maxHistoryCount {
            nonFavorites = Array(nonFavorites.prefix(maxHistoryCount))
        }
        data.items = nonFavorites + favorites.filter { nf in !nonFavorites.contains(where: { $0.id == nf.id }) }
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
}

// MARK: - Time Formatting Helper
private let _fmtShort: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "MM-dd HH:mm"; return f
}()
private let _fmtFull: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd HH:mm"; return f
}()

func formatTime(_ timestamp: Double) -> String {
    let date = Date(timeIntervalSince1970: timestamp)
    let now = Date()
    let diff = now.timeIntervalSince(date)

    if diff < 60 { return "刚刚" }
    if diff < 3600 { return "\(Int(diff / 60)) 分钟前" }
    if diff < 86400 { return "\(Int(diff / 3600)) 小时前" }

    let cal = Calendar.current
    let isThisYear = cal.component(.year, from: date) == cal.component(.year, from: now)
    return isThisYear ? _fmtShort.string(from: date) : _fmtFull.string(from: date)
}

// MARK: - Pill Badge View (for counts)
class PillBadge: NSView {
    var text: String = "0" { didSet { needsDisplay = true } }
    var isActive: Bool = false { didSet { needsDisplay = true } }

    override var intrinsicContentSize: NSSize {
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 11)]
        let size = (text as NSString).size(withAttributes: attrs)
        return NSSize(width: max(size.width + 14, 24), height: 18)
    }

    override func draw(_ dirtyRect: NSRect) {
        let bg = isActive ? Theme.accentDim : Theme.bgOverlay
        let fg = isActive ? Theme.accent : Theme.textMuted
        let path = NSBezierPath(roundedRect: bounds, xRadius: 9, yRadius: 9)
        bg.setFill()
        path.fill()
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: isActive ? .medium : .regular),
            .foregroundColor: fg
        ]
        let size = (text as NSString).size(withAttributes: attrs)
        let point = NSPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2)
        (text as NSString).draw(at: point, withAttributes: attrs)
    }
}

// MARK: - Tab Button
class TabButton: NSButton {
    var tabId: String = ""
    var isActiveTab: Bool = false { didSet { needsDisplay = true } }
    let badge = PillBadge()
    private var trackingArea: NSTrackingArea?
    var isHovered = false

    init(title: String, icon: String, tabId: String) {
        super.init(frame: .zero)
        self.tabId = tabId
        self.title = ""
        self.isBordered = false
        self.bezelStyle = .inline
        self.wantsLayer = true

        badge.translatesAutoresizingMaskIntoConstraints = false
        addSubview(badge)

        // Store display title
        self.toolTip = title
        setAccessibilityLabel(title)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let ta = trackingArea { removeTrackingArea(ta) }
        trackingArea = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeInKeyWindow], owner: self, userInfo: nil)
        addTrackingArea(trackingArea!)
    }

    override func mouseEntered(with event: NSEvent) { isHovered = true; needsDisplay = true }
    override func mouseExited(with event: NSEvent) { isHovered = false; needsDisplay = true }

    override func draw(_ dirtyRect: NSRect) {
        let bg: NSColor
        if isActiveTab {
            bg = Theme.bgBase
        } else if isHovered {
            bg = Theme.bgHover
        } else {
            bg = .clear
        }

        let path = NSBezierPath(roundedRect: bounds, xRadius: 7, yRadius: 7)
        bg.setFill()
        path.fill()

        if isActiveTab {
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.06)
            shadow.shadowOffset = NSSize(width: 0, height: -1)
            shadow.shadowBlurRadius = 3
            shadow.set()
            bg.setFill()
            path.fill()
        }

        // Draw label
        let icons = ["history": "📋", "favorites": "⭐"]
        let titles = ["history": "历史", "favorites": "收藏"]
        let icon = icons[tabId] ?? ""
        let label = titles[tabId] ?? ""
        let fullLabel = "\(icon) \(label)"

        let fg = isActiveTab ? Theme.textPrimary : Theme.textSecondary
        let weight: NSFont.Weight = isActiveTab ? .semibold : .medium
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: weight),
            .foregroundColor: fg
        ]
        let labelSize = (fullLabel as NSString).size(withAttributes: attrs)
        let badgeW = badge.intrinsicContentSize.width
        let totalW = labelSize.width + 6 + badgeW
        let startX = (bounds.width - totalW) / 2
        let labelY = (bounds.height - labelSize.height) / 2
        (fullLabel as NSString).draw(at: NSPoint(x: startX, y: labelY), withAttributes: attrs)

        // Position badge
        badge.frame = NSRect(x: startX + labelSize.width + 6,
                            y: (bounds.height - 18) / 2,
                            width: badgeW, height: 18)
        badge.isActive = isActiveTab
    }
}

// MARK: - Clipboard Item Cell View
class ClipboardItemCellView: NSTableCellView {
    let contentLabel = NSTextField(labelWithString: "")
    let metaLabel = NSTextField(labelWithString: "")
    let favButton = NSButton()
    let deleteButton = NSButton()
    let actionsStack = NSStackView()

    var onToggleFav: ((String) -> Void)?
    var onDelete: ((String) -> Void)?
    var itemId: String = ""
    var isItemSelected: Bool = false { didSet { needsDisplay = true } }

    private var trackingArea: NSTrackingArea?
    private var isHovered = false { didSet { updateActionsVisibility() } }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    func setup() {
        wantsLayer = true

        contentLabel.font = NSFont.systemFont(ofSize: 13)
        contentLabel.textColor = Theme.textPrimary
        contentLabel.lineBreakMode = .byTruncatingTail
        contentLabel.maximumNumberOfLines = 1
        contentLabel.translatesAutoresizingMaskIntoConstraints = false

        metaLabel.font = NSFont.systemFont(ofSize: 11)
        metaLabel.textColor = Theme.textMuted
        metaLabel.lineBreakMode = .byTruncatingTail
        metaLabel.maximumNumberOfLines = 1
        metaLabel.translatesAutoresizingMaskIntoConstraints = false

        let textStack = NSStackView(views: [contentLabel, metaLabel])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 3
        textStack.translatesAutoresizingMaskIntoConstraints = false

        favButton.title = "☆"
        favButton.font = NSFont.systemFont(ofSize: 14)
        favButton.isBordered = false
        favButton.target = self
        favButton.action = #selector(favClicked)
        favButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            favButton.widthAnchor.constraint(equalToConstant: 28),
            favButton.heightAnchor.constraint(equalToConstant: 28)
        ])

        deleteButton.title = "✕"
        deleteButton.font = NSFont.systemFont(ofSize: 14)
        deleteButton.isBordered = false
        deleteButton.target = self
        deleteButton.action = #selector(deleteClicked)
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            deleteButton.widthAnchor.constraint(equalToConstant: 28),
            deleteButton.heightAnchor.constraint(equalToConstant: 28)
        ])

        actionsStack.addArrangedSubview(favButton)
        actionsStack.addArrangedSubview(deleteButton)
        actionsStack.orientation = .horizontal
        actionsStack.spacing = 4
        actionsStack.translatesAutoresizingMaskIntoConstraints = false
        actionsStack.alphaValue = 0

        addSubview(textStack)
        addSubview(actionsStack)

        NSLayoutConstraint.activate([
            textStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            textStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: actionsStack.leadingAnchor, constant: -10),

            actionsStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            actionsStack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    func configure(item: ClipboardItem, selected: Bool) {
        itemId = item.id
        isItemSelected = selected

        let preview = item.content.prefix(200).replacingOccurrences(of: "\n", with: " ↵ ")
        contentLabel.stringValue = preview

        let time = formatTime(item.timestamp)
        metaLabel.stringValue = "\(time)  ·  \(item.content.count) 字符"

        favButton.title = item.favorite ? "★" : "☆"
        favButton.contentTintColor = item.favorite ? Theme.yellow : Theme.textMuted

        // 配置时直接设置，不做动画（避免 reloadData 时 100 个 cell 同时触发动画）
        actionsStack.alphaValue = (isHovered || isItemSelected) ? 1 : 0
    }

    func updateActionsVisibility() {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.15
            actionsStack.animator().alphaValue = (isHovered || isItemSelected) ? 1 : 0
        })
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let ta = trackingArea { removeTrackingArea(ta) }
        trackingArea = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self, userInfo: nil)
        addTrackingArea(trackingArea!)
    }

    override func mouseEntered(with event: NSEvent) { isHovered = true }
    override func mouseExited(with event: NSEvent) { isHovered = false }

    override func draw(_ dirtyRect: NSRect) {
        if isItemSelected {
            Theme.bgSelected.setFill()
            bounds.fill()
            Theme.accent.setFill()
            NSRect(x: 0, y: 0, width: 3, height: bounds.height).fill()
        }

        // Bottom border
        Theme.border.setStroke()
        let line = NSBezierPath()
        line.move(to: NSPoint(x: 0, y: 0))
        line.line(to: NSPoint(x: bounds.width, y: 0))
        line.lineWidth = 0.5
        line.stroke()
    }

    @objc func favClicked() { onToggleFav?(itemId) }
    @objc func deleteClicked() { onDelete?(itemId) }
}

// MARK: - Main Content View Controller
class MainViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {
    let searchField = NSSearchField()
    let tabBar = NSView()
    var tabButtons: [TabButton] = []
    let tableView = NSTableView()
    let scrollView = NSScrollView()
    let emptyStateView = NSView()
    let footerButton = NSButton()

    var currentTab = "history"
    var selectedIndex = 0
    var filteredItems: [ClipboardItem] = []
    let listDisplayLimit = 100

    var onPasteItem: ((ClipboardItem) -> Void)?
    var onHideWindow: (() -> Void)?

    // 搜索防抖
    private var searchDebounceTimer: Timer?
    // 缓存排好序的数据，避免每次 filter/sort
    private var cachedHistoryItems: [ClipboardItem]?
    private var cachedFavoriteItems: [ClipboardItem]?

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 680, height: 492))
        view.wantsLayer = true
        view.layer?.backgroundColor = Theme.bgBase.cgColor
        setupUI()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        reloadData()
    }

    func setupUI() {
        // Search field
        searchField.placeholderString = "搜索剪切板内容..."
        searchField.font = NSFont.systemFont(ofSize: 14)
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.delegate = self
        searchField.focusRingType = .exterior
        view.addSubview(searchField)

        // Tab bar
        tabBar.wantsLayer = true
        tabBar.layer?.backgroundColor = Theme.bgSurface.cgColor
        tabBar.layer?.cornerRadius = 10
        tabBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tabBar)

        let tabIds = ["history", "favorites"]
        let tabNames = ["历史", "收藏"]
        let tabIcons = ["📋", "⭐"]
        for i in 0..<2 {
            let btn = TabButton(title: tabNames[i], icon: tabIcons[i], tabId: tabIds[i])
            btn.translatesAutoresizingMaskIntoConstraints = false
            btn.target = self
            btn.action = #selector(tabClicked(_:))
            btn.isActiveTab = (i == 0)
            tabBar.addSubview(btn)
            tabButtons.append(btn)
        }

        // Layout tabs evenly
        NSLayoutConstraint.activate([
            tabButtons[0].leadingAnchor.constraint(equalTo: tabBar.leadingAnchor, constant: 3),
            tabButtons[0].topAnchor.constraint(equalTo: tabBar.topAnchor, constant: 3),
            tabButtons[0].bottomAnchor.constraint(equalTo: tabBar.bottomAnchor, constant: -3),

            tabButtons[1].leadingAnchor.constraint(equalTo: tabButtons[0].trailingAnchor, constant: 2),
            tabButtons[1].topAnchor.constraint(equalTo: tabBar.topAnchor, constant: 3),
            tabButtons[1].bottomAnchor.constraint(equalTo: tabBar.bottomAnchor, constant: -3),
            tabButtons[1].trailingAnchor.constraint(equalTo: tabBar.trailingAnchor, constant: -3),
            tabButtons[1].widthAnchor.constraint(equalTo: tabButtons[0].widthAnchor),
        ])

        // TableView (for history/favorites)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.headerView = nil
        tableView.backgroundColor = Theme.bgBase
        tableView.rowHeight = 52
        tableView.selectionHighlightStyle = .none
        tableView.intercellSpacing = NSSize(width: 0, height: 0)
        tableView.usesAlternatingRowBackgroundColors = false

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("content"))
        column.title = ""
        tableView.addTableColumn(column)

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.wantsLayer = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = true
        scrollView.backgroundColor = Theme.bgBase
        view.addSubview(scrollView)

        // Empty state
        setupEmptyState()
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.isHidden = true
        view.addSubview(emptyStateView)

        // Data file button (next to search field)
        footerButton.title = "📂"
        footerButton.font = NSFont.systemFont(ofSize: 13)
        footerButton.isBordered = false
        footerButton.contentTintColor = Theme.textSecondary
        footerButton.target = self
        footerButton.action = #selector(footerButtonClicked)
        footerButton.translatesAutoresizingMaskIntoConstraints = false
        footerButton.toolTip = "打开数据文件"
        view.addSubview(footerButton)

        // Layout
        let hPadding: CGFloat = 8
        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: view.topAnchor, constant: 0),
            searchField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: hPadding),
            searchField.trailingAnchor.constraint(equalTo: footerButton.leadingAnchor, constant: -4),
            searchField.heightAnchor.constraint(equalToConstant: 32),

            footerButton.centerYAnchor.constraint(equalTo: searchField.centerYAnchor),
            footerButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -hPadding),
            footerButton.widthAnchor.constraint(equalToConstant: 28),
            footerButton.heightAnchor.constraint(equalToConstant: 28),

            tabBar.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 10),
            tabBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: hPadding),
            tabBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -hPadding),
            tabBar.heightAnchor.constraint(equalToConstant: 36),

            scrollView.topAnchor.constraint(equalTo: tabBar.bottomAnchor, constant: 10),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: hPadding),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -hPadding),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -4),

            emptyStateView.topAnchor.constraint(equalTo: tabBar.bottomAnchor, constant: 10),
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: hPadding),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -hPadding),
            emptyStateView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -4),
        ])

        // Double click to paste
        tableView.doubleAction = #selector(tableViewDoubleClicked)
        tableView.target = self
    }

    func setupEmptyState() {
        emptyStateView.wantsLayer = true
        emptyStateView.layer?.backgroundColor = Theme.bgBase.cgColor

        let iconLabel = NSTextField(labelWithString: "📋")
        iconLabel.font = NSFont.systemFont(ofSize: 40)
        iconLabel.alignment = .center
        iconLabel.alphaValue = 0.5
        iconLabel.translatesAutoresizingMaskIntoConstraints = false

        let textLabel = NSTextField(labelWithString: "暂无剪切板记录\n复制一些内容试试")
        textLabel.font = NSFont.systemFont(ofSize: 14)
        textLabel.textColor = Theme.textMuted
        textLabel.alignment = .center
        textLabel.maximumNumberOfLines = 0
        textLabel.translatesAutoresizingMaskIntoConstraints = false

        emptyStateView.addSubview(iconLabel)
        emptyStateView.addSubview(textLabel)

        // We tag them for updates
        iconLabel.tag = 1001
        textLabel.tag = 1002

        NSLayoutConstraint.activate([
            iconLabel.centerXAnchor.constraint(equalTo: emptyStateView.centerXAnchor),
            iconLabel.centerYAnchor.constraint(equalTo: emptyStateView.centerYAnchor, constant: -20),
            textLabel.centerXAnchor.constraint(equalTo: emptyStateView.centerXAnchor),
            textLabel.topAnchor.constraint(equalTo: iconLabel.bottomAnchor, constant: 12),
        ])
    }

    func updateEmptyState(icon: String, text: String) {
        if let iconLabel = emptyStateView.viewWithTag(1001) as? NSTextField {
            iconLabel.stringValue = icon
        }
        if let textLabel = emptyStateView.viewWithTag(1002) as? NSTextField {
            textLabel.stringValue = text
        }
    }

    /// 清除缓存，下次 reloadData 时重新从 DataManager 获取
    func invalidateCache() {
        cachedHistoryItems = nil
        cachedFavoriteItems = nil
    }

    /// 获取当前 tab 对应的已排序数据（带缓存）
    private func currentTabItems() -> [ClipboardItem] {
        if currentTab == "history" {
            if cachedHistoryItems == nil {
                cachedHistoryItems = DataManager.shared.getHistoryItems()
            }
            return cachedHistoryItems!
        } else {
            if cachedFavoriteItems == nil {
                cachedFavoriteItems = DataManager.shared.getFavoriteItems()
            }
            return cachedFavoriteItems!
        }
    }

    func reloadData() {
        let items = currentTabItems()

        let query = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty {
            filteredItems = Array(items.prefix(listDisplayLimit))
        } else {
            filteredItems = items.filter { $0.content.range(of: query, options: .caseInsensitive) != nil }
            filteredItems = Array(filteredItems.prefix(listDisplayLimit))
        }

        if selectedIndex >= filteredItems.count {
            selectedIndex = max(0, filteredItems.count - 1)
        }

        if filteredItems.isEmpty {
            scrollView.isHidden = true
            emptyStateView.isHidden = false
            let isSearching = !query.isEmpty
            if isSearching {
                updateEmptyState(icon: "🔍", text: "没有找到匹配的内容")
            } else if currentTab == "favorites" {
                updateEmptyState(icon: "⭐", text: "暂无收藏内容\n选中条目按 ⌘S 收藏")
            } else {
                updateEmptyState(icon: "📋", text: "暂无剪切板记录\n复制一些内容试试")
            }
        } else {
            scrollView.isHidden = false
            emptyStateView.isHidden = true
            tableView.reloadData()
            if selectedIndex < filteredItems.count {
                tableView.selectRowIndexes(IndexSet(integer: selectedIndex), byExtendingSelection: false)
                tableView.scrollRowToVisible(selectedIndex)
            }
        }

        updateTabCounts()
    }

    func updateTabCounts() {
        // 使用缓存，避免重复 filter + sort
        if cachedHistoryItems == nil {
            cachedHistoryItems = DataManager.shared.getHistoryItems()
        }
        if cachedFavoriteItems == nil {
            cachedFavoriteItems = DataManager.shared.getFavoriteItems()
        }
        let historyCount = cachedHistoryItems!.count
        let favCount = cachedFavoriteItems!.count

        tabButtons[0].badge.text = historyCount > listDisplayLimit ? "\(listDisplayLimit)/\(historyCount)" : "\(historyCount)"
        tabButtons[1].badge.text = "\(favCount)"
        tabButtons.forEach { $0.badge.invalidateIntrinsicContentSize(); $0.needsDisplay = true }
    }

    func switchTab(_ tab: String) {
        guard currentTab != tab else { return }
        currentTab = tab
        selectedIndex = 0
        searchField.stringValue = ""
        invalidateCache()

        for btn in tabButtons {
            btn.isActiveTab = (btn.tabId == tab)
        }

        searchField.placeholderString = "搜索剪切板内容..."
        reloadData()
    }

    func switchToNextTab(direction: Int) {
        let tabs = ["history", "favorites"]
        guard let idx = tabs.firstIndex(of: currentTab) else { return }
        let next = (idx + direction + tabs.count) % tabs.count
        switchTab(tabs[next])
    }

    func focusSearch() {
        searchField.stringValue = ""
        view.window?.makeFirstResponder(searchField)
        selectedIndex = 0
        reloadData()
    }

    // MARK: - Actions
    @objc func tabClicked(_ sender: TabButton) {
        switchTab(sender.tabId)
    }

    @objc func footerButtonClicked() {
        if FileManager.default.fileExists(atPath: dataFile) {
            NSWorkspace.shared.open(URL(fileURLWithPath: dataFile))
        } else {
            NSWorkspace.shared.open(URL(fileURLWithPath: dataDir))
        }
    }

    @objc func tableViewDoubleClicked() {
        let row = tableView.clickedRow
        guard row >= 0 && row < filteredItems.count else { return }
        let item = filteredItems[row]
        DataManager.shared.useItem(id: item.id)
        onPasteItem?(item)
    }

    // MARK: - NSTableViewDataSource
    func numberOfRows(in tableView: NSTableView) -> Int {
        return filteredItems.count
    }

    // MARK: - NSTableViewDelegate
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let id = NSUserInterfaceItemIdentifier("ClipboardCell")
        var cellView = tableView.makeView(withIdentifier: id, owner: self) as? ClipboardItemCellView
        if cellView == nil {
            cellView = ClipboardItemCellView(frame: NSRect(x: 0, y: 0, width: tableView.bounds.width, height: 52))
            cellView?.identifier = id
        }

        let item = filteredItems[row]
        cellView?.configure(item: item, selected: row == selectedIndex)
        cellView?.onToggleFav = { [weak self] id in
            DataManager.shared.toggleFavorite(id: id)
            self?.invalidateCache()
            self?.reloadData()
        }
        cellView?.onDelete = { [weak self] id in
            DataManager.shared.deleteItem(id: id)
            self?.invalidateCache()
            self?.reloadData()
        }
        return cellView
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 52
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = tableView.selectedRow
        if row >= 0 && row != selectedIndex {
            let oldIndex = selectedIndex
            selectedIndex = row
            // 只刷新旧行和新行，不全量 reload
            var rowsToRefresh = IndexSet(integer: row)
            if oldIndex < filteredItems.count { rowsToRefresh.insert(oldIndex) }
            let colSet = IndexSet(integer: 0)
            tableView.reloadData(forRowIndexes: rowsToRefresh, columnIndexes: colSet)
        }
    }
}

// MARK: - NSSearchFieldDelegate
extension MainViewController: NSSearchFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        searchDebounceTimer?.invalidate()
        searchDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { [weak self] _ in
            self?.selectedIndex = 0
            self?.reloadData()
        }
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var mainVC: MainViewController!
    private var signalSource: DispatchSourceSignal?
    private var clipboardTimer: Timer?
    private var lastChangeCount: Int = 0
    private var isWindowVisible = false
    private var previousApp: NSRunningApplication?
    private var isPasting = false
    private var isOpeningFile = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupMenuBar()
        writePIDFile()
        setupSignalHandler()
        createWindow()

        lastChangeCount = NSPasteboard.general.changeCount
        startClipboardMonitoring()

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

    // MARK: - Signal Handler
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
            mainVC?.invalidateCache()
            mainVC?.reloadData()
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

        mainVC = MainViewController()
        mainVC.onPasteItem = { [weak self] item in
            self?.pasteContent(item.content)
        }
        mainVC.onHideWindow = { [weak self] in
            self?.hideWindow()
        }

        // Add titlebar drag area + main content
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight))
        containerView.autoresizingMask = [.width, .height]

        let titlebarHeight: CGFloat = 28
        let mainView = mainVC.view
        mainView.frame = NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight - titlebarHeight)
        mainView.autoresizingMask = [.width, .height]
        containerView.addSubview(mainView)

        window.contentView = containerView
    }

    func showWindow() {
        previousApp = NSWorkspace.shared.frontmostApplication

        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        isWindowVisible = true
        mainVC?.invalidateCache()
        mainVC?.reloadData()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.mainVC?.focusSearch()
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

    // MARK: - Paste to Previous App
    func pasteContent(_ content: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(content, forType: .string)
        lastChangeCount = pb.changeCount

        isPasting = true
        hideWindow()

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
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        keyDown?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        keyUp?.flags = .maskCommand
        keyUp?.post(tap: .cghidEventTap)
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

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
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

// MARK: - Keyboard Event Handling (via NSApplication subclass)
class ClipboardApp: NSApplication {
    var appDelegateRef: AppDelegate? { return delegate as? AppDelegate }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown {
            guard let mainVC = appDelegateRef?.mainVC else {
                super.sendEvent(event)
                return
            }

            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

            // ESC
            if event.keyCode == 53 {
                appDelegateRef?.hideWindow()
                return
            }

            // Tab (no modifiers or Shift) - switch tabs
            if event.keyCode == 48 && (flags == [] || flags == .shift) {
                let dir: Int = flags == .shift ? -1 : 1
                mainVC.switchToNextTab(direction: dir)
                return
            }

            // Cmd+F - focus search
            if event.charactersIgnoringModifiers == "f" && flags == .command {
                mainVC.focusSearch()
                return
            }

            // Cmd+S - toggle favorite
            if event.charactersIgnoringModifiers == "s" && flags == .command {
                if mainVC.selectedIndex < mainVC.filteredItems.count {
                    let item = mainVC.filteredItems[mainVC.selectedIndex]
                    DataManager.shared.toggleFavorite(id: item.id)
                    mainVC.reloadData()
                }
                return
            }

            // Arrow Up
            if event.keyCode == 126 {
                if mainVC.filteredItems.count > 0 {
                    let oldIndex = mainVC.selectedIndex
                    mainVC.selectedIndex = max(0, mainVC.selectedIndex - 1)
                    if oldIndex != mainVC.selectedIndex {
                        mainVC.tableView.selectRowIndexes(IndexSet(integer: mainVC.selectedIndex), byExtendingSelection: false)
                        mainVC.tableView.scrollRowToVisible(mainVC.selectedIndex)
                        var rows = IndexSet(integer: mainVC.selectedIndex)
                        if oldIndex < mainVC.filteredItems.count { rows.insert(oldIndex) }
                        mainVC.tableView.reloadData(forRowIndexes: rows, columnIndexes: IndexSet(integer: 0))
                    }
                }
                return
            }

            // Arrow Down
            if event.keyCode == 125 {
                if mainVC.filteredItems.count > 0 {
                    let oldIndex = mainVC.selectedIndex
                    mainVC.selectedIndex = min(mainVC.filteredItems.count - 1, mainVC.selectedIndex + 1)
                    if oldIndex != mainVC.selectedIndex {
                        mainVC.tableView.selectRowIndexes(IndexSet(integer: mainVC.selectedIndex), byExtendingSelection: false)
                        mainVC.tableView.scrollRowToVisible(mainVC.selectedIndex)
                        var rows = IndexSet(integer: mainVC.selectedIndex)
                        if oldIndex < mainVC.filteredItems.count { rows.insert(oldIndex) }
                        mainVC.tableView.reloadData(forRowIndexes: rows, columnIndexes: IndexSet(integer: 0))
                    }
                }
                return
            }

            // Arrow Left/Right - switch tabs (when not in search field with text)
            if event.keyCode == 123 || event.keyCode == 124 {
                let isInSearch = mainVC.view.window?.firstResponder is NSTextView &&
                    mainVC.searchField.currentEditor() != nil
                if isInSearch && !mainVC.searchField.stringValue.isEmpty {
                    // Let search field handle cursor
                    super.sendEvent(event)
                    return
                }
                let dir = event.keyCode == 123 ? -1 : 1
                mainVC.switchToNextTab(direction: dir)
                return
            }

            // Enter - paste selected item
            if event.keyCode == 36 {
                if mainVC.selectedIndex < mainVC.filteredItems.count {
                    let item = mainVC.filteredItems[mainVC.selectedIndex]
                    DataManager.shared.useItem(id: item.id)
                    mainVC.onPasteItem?(item)
                }
                return
            }

            // Cmd+Delete - delete item
            if event.keyCode == 51 && flags == .command {
                if mainVC.selectedIndex < mainVC.filteredItems.count {
                    let item = mainVC.filteredItems[mainVC.selectedIndex]
                    DataManager.shared.deleteItem(id: item.id)
                    mainVC.invalidateCache()
                    mainVC.reloadData()
                }
                return
            }
        }

        super.sendEvent(event)
    }
}

// MARK: - Entry Point
// Use our custom NSApplication subclass for keyboard handling
let app = ClipboardApp.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
