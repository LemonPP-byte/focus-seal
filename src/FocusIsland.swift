// FocusIsland — 刘海下的目标胶囊
// 平时藏在刘海里看不见；只在这几个时刻探出来几秒再缩回：
//   1) 目标改了——休息结束时在封屏上写完目标，或 `focusseal goal "..."`，探出来确认
//   2) 休息前 5 分钟（:25 / :55）——提醒收尾
//   3) 鼠标停在刘海附近——瞄一眼
// 目标写在 ~/.focus-seal/goal.txt。
// 编译：swiftc -O -o bin/focus-island FocusIsland.swift -framework Cocoa

import Cocoa

// ===== 可调参数 =====
let GOAL_FILE = NSString(string: "~/.focus-seal/goal.txt").expandingTildeInPath
let PEEK_SECONDS: TimeInterval = 6      // 定时探出停留多久
let HOVER_DWELL: TimeInterval = 0.3     // 鼠标在刘海附近停多久才展开（防误触）
let HOVER_LINGER: TimeInterval = 0.8    // 鼠标移开后多久收起
let ROW_HEIGHT: CGFloat = 30            // 刘海下方文字行高度
let SIDE_PAD: CGFloat = 20
let MAX_WIDTH: CGFloat = 520

func readGoal() -> String {
    ((try? String(contentsOfFile: GOAL_FILE, encoding: .utf8)) ?? "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

func goalMTime() -> Date? {
    (try? FileManager.default.attributesOfItem(atPath: GOAL_FILE))?[.modificationDate] as? Date
}

// 距下一次封屏（:00 / :30）还有几分钟
func minutesToBreak(_ now: Date = Date()) -> Int {
    let c = Calendar.current.dateComponents([.minute, .second], from: now)
    let into = (c.minute! % 30) * 60 + c.second!
    return Int((Double(1800 - into) / 60).rounded(.up))
}

// 带刘海的屏幕优先；外接显示器为主屏时仍然挂在内建屏上
func islandScreen() -> NSScreen {
    NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main ?? NSScreen.screens[0]
}

// 刘海在屏幕坐标里的矩形；没有刘海时退化成菜单栏正中一段
func notchRect(on s: NSScreen) -> NSRect {
    let f = s.frame
    if s.safeAreaInsets.top > 0, let l = s.auxiliaryTopLeftArea, let r = s.auxiliaryTopRightArea {
        let h = s.safeAreaInsets.top
        return NSRect(x: l.maxX, y: f.maxY - h, width: r.minX - l.maxX, height: h)
    }
    let h = max(22, f.maxY - s.visibleFrame.maxY)
    return NSRect(x: f.midX - 90, y: f.maxY - h, width: 180, height: h)
}

final class IslandWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    // 不让系统把窗口挤出菜单栏区域
    override func constrainFrameRect(_ r: NSRect, to s: NSScreen?) -> NSRect { r }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: IslandWindow!
    let pill = NSView()
    let goalLabel = NSTextField(labelWithString: "")
    let timeLabel = NSTextField(labelWithString: "")

    var notch = NSRect.zero          // 屏幕坐标
    var expanded = false
    var hideAt: Date? = nil
    var hoverStart: Date? = nil
    var lastSlot = ""
    var lastMTime: Date? = goalMTime()

    func applicationDidFinishLaunching(_ n: Notification) {
        NSApp.setActivationPolicy(.accessory)

        window = IslandWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true      // 永远点穿，不挡菜单栏
        window.level = .statusBar
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        window.alphaValue = 0

        let root = NSView()
        window.contentView = root
        pill.wantsLayer = true
        pill.layer?.backgroundColor = NSColor.black.cgColor
        pill.layer?.cornerRadius = 16
        pill.layer?.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]  // 只圆底边，顶边和刘海无缝
        pill.layer?.masksToBounds = true
        root.addSubview(pill)

        goalLabel.font = .systemFont(ofSize: 13, weight: .medium)
        goalLabel.lineBreakMode = .byTruncatingTail
        timeLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        timeLabel.textColor = NSColor(white: 1, alpha: 0.42)
        for l in [goalLabel, timeLabel] {
            l.alphaValue = 0
            l.autoresizingMask = []
            pill.addSubview(l)
        }

        placeWindow()
        NotificationCenter.default.addObserver(
            self, selector: #selector(placeWindow),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)

        Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in self?.tick() }

        // 开机/登录时探一下，确认它在
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { self.peek(4) }
    }

    @objc func placeWindow() {
        let s = islandScreen()
        notch = notchRect(on: s)
        let h = notch.height + ROW_HEIGHT
        window.setFrame(NSRect(x: notch.midX - MAX_WIDTH / 2, y: s.frame.maxY - h,
                               width: MAX_WIDTH, height: h), display: false)
        window.orderFrontRegardless()
        if !expanded { pill.frame = collapsedFrame() }
    }

    // ---- 几何（窗口内坐标）----
    func collapsedFrame() -> NSRect {
        NSRect(x: notch.minX - window.frame.minX, y: window.frame.height - notch.height,
               width: notch.width, height: notch.height)
    }

    func refreshLabels() -> NSRect {
        let goal = readGoal()
        if goal.isEmpty {
            goalLabel.stringValue = "这一段做什么？"
            goalLabel.textColor = NSColor(white: 1, alpha: 0.55)
        } else {
            goalLabel.stringValue = goal
            goalLabel.textColor = NSColor(white: 1, alpha: 0.92)
        }
        timeLabel.stringValue = "\(minutesToBreak()) 分钟"

        goalLabel.sizeToFit(); timeLabel.sizeToFit()
        let gap: CGFloat = 14
        let maxGoal = MAX_WIDTH - 2 * SIDE_PAD - gap - timeLabel.frame.width
        let gw = min(goalLabel.frame.width, maxGoal)
        let w = max(notch.width + 48, gw + gap + timeLabel.frame.width + 2 * SIDE_PAD)
        let h = notch.height + ROW_HEIGHT
        let target = NSRect(x: (MAX_WIDTH - w) / 2, y: 0, width: w, height: h)

        // 文字排在刘海下方那一行，左目标右倒计时
        let gy = (ROW_HEIGHT - goalLabel.frame.height) / 2 + 2
        let ty = (ROW_HEIGHT - timeLabel.frame.height) / 2 + 2
        goalLabel.frame = NSRect(x: SIDE_PAD, y: gy, width: gw, height: goalLabel.frame.height)
        timeLabel.frame = NSRect(x: w - SIDE_PAD - timeLabel.frame.width, y: ty,
                                 width: timeLabel.frame.width, height: timeLabel.frame.height)
        return target
    }

    // ---- 展开 / 收起 ----
    func peek(_ secs: TimeInterval) {
        let until = Date().addingTimeInterval(secs)
        hideAt = max(hideAt ?? until, until)
        expand()
    }

    func expand() {
        let target = refreshLabels()
        if expanded {
            NSAnimationContext.runAnimationGroup { c in
                c.duration = 0.25
                pill.animator().frame = target
            }
            return
        }
        expanded = true
        pill.frame = collapsedFrame()
        window.alphaValue = 1
        NSAnimationContext.runAnimationGroup({ c in
            c.duration = 0.38
            c.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.25, 1.0)
            pill.animator().frame = target
        }) {
            guard self.expanded else { return }
            NSAnimationContext.runAnimationGroup { c in
                c.duration = 0.22
                self.goalLabel.animator().alphaValue = 1
                self.timeLabel.animator().alphaValue = 1
            }
        }
    }

    func collapse() {
        expanded = false
        hideAt = nil
        NSAnimationContext.runAnimationGroup({ c in
            c.duration = 0.15
            goalLabel.animator().alphaValue = 0
            timeLabel.animator().alphaValue = 0
        }) {
            guard !self.expanded else { return }
            NSAnimationContext.runAnimationGroup({ c in
                c.duration = 0.3
                c.timingFunction = CAMediaTimingFunction(name: .easeIn)
                self.pill.animator().frame = self.collapsedFrame()
            }) {
                guard !self.expanded else { return }
                self.window.alphaValue = 0
            }
        }
    }

    // ---- 每 0.15 秒 ----
    func tick() {
        let now = Date()

        // 定时探出：休息前 5 分钟（休息结束由封屏的写目标环节接管）
        let c = Calendar.current.dateComponents([.hour, .minute], from: now)
        let slot = "\(c.hour!):\(c.minute!)"
        if [25, 55].contains(c.minute!), slot != lastSlot {
            lastSlot = slot
            peek(PEEK_SECONDS)
        }

        // 目标改了就探出来确认
        let m = goalMTime()
        if m != lastMTime {
            lastMTime = m
            peek(4)
        }

        // 悬停
        let mouse = NSEvent.mouseLocation
        let hot = notch.insetBy(dx: -24, dy: 0).union(notch.offsetBy(dx: 0, dy: 4))
        let pillOnScreen = pill.frame.offsetBy(dx: window.frame.minX, dy: window.frame.minY)
        let inside = hot.contains(mouse) || (expanded && pillOnScreen.insetBy(dx: -12, dy: -12).contains(mouse))
        if inside {
            if hoverStart == nil { hoverStart = now }
            if now.timeIntervalSince(hoverStart!) >= HOVER_DWELL {
                let until = now.addingTimeInterval(HOVER_LINGER)
                hideAt = max(hideAt ?? until, until)
                if !expanded { expand() }
            }
        } else {
            hoverStart = nil
        }

        if expanded {
            timeLabel.stringValue = "\(minutesToBreak()) 分钟"
            if let h = hideAt, now >= h { collapse() }
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
