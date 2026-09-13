// FocusSeal — 整点强制休息封条
// 在整点 :00 和 :30 各封屏 5 分钟，一个巨大的黑色 X 横铺全屏。
// 解锁：直接键入解锁短语（默认 overridebreak）。
// 编译：swiftc -O -o bin/focus-seal FocusSeal.swift -framework Cocoa

import Cocoa

// ===== 可调参数 =====
let UNLOCK_PHRASE = "overridebreak"   // 强力解锁短语，键入即解封
let SCRIM_ALPHA: CGFloat = 0.93       // X 以外区域的遮黑程度
let X_THICKNESS: CGFloat = 0.13       // X 笔画粗细，占屏幕短边比例
let HARD_LIMIT: TimeInterval = 420    // 失效保险：超过这个秒数无条件退出

// ===== 命令行参数 =====
var argSeconds: TimeInterval? = nil
var argAlign = false
let args = CommandLine.arguments
var i = 1
while i < args.count {
    switch args[i] {
    case "--seconds":
        if i + 1 < args.count { argSeconds = TimeInterval(args[i + 1]) ?? 300; i += 1 }
    case "--align":
        argAlign = true
    default:
        break
    }
    i += 1
}

// 计算本次封屏应持续多久
func computeDuration(_ now: Date = Date()) -> TimeInterval {
    if let s = argSeconds { return max(5, s) }
    guard argAlign else { return 300 }
    // 对齐到 :00 / :30 起算的 5 分钟窗口
    let cal = Calendar.current
    let minute = cal.component(.minute, from: now)
    var comps = cal.dateComponents([.year, .month, .day, .hour], from: now)
    comps.minute = minute < 30 ? 0 : 30
    comps.second = 0
    guard let boundary = cal.date(from: comps) else { return 300 }
    let remaining = boundary.addingTimeInterval(300).timeIntervalSince(now)
    // 若因睡眠/唤醒错过窗口，补一个 60 秒的短休息，而不是完全跳过
    return remaining < 60 ? 60 : remaining
}

// --dry [--at HH:MM:SS]：只打印算出来的时长，不封屏（用于验证调度对齐）
if args.contains("--dry") {
    let f = DateFormatter(); f.dateFormat = "HH:mm:ss"
    var probe = Date()
    if let k = args.firstIndex(of: "--at"), k + 1 < args.count {
        let parts = args[k + 1].split(separator: ":").compactMap { Int($0) }
        if parts.count == 3 {
            var c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
            c.hour = parts[0]; c.minute = parts[1]; c.second = parts[2]
            probe = Calendar.current.date(from: c) ?? probe
        }
    }
    let d = computeDuration(probe)
    print("at=\(f.string(from: probe))  duration=\(Int(d))s  end=\(f.string(from: probe.addingTimeInterval(d)))")
    exit(0)
}

let DURATION = computeDuration()

// ===== 封条视图 =====
final class SealView: NSView {
    var remaining: TimeInterval = DURATION
    var typed = ""
    var isPrimary = false   // 只在主屏显示倒计时文字

    override var isOpaque: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let r = bounds
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        // 1) 全屏遮黑（X 以外的区域）
        NSColor(white: 0.0, alpha: SCRIM_ALPHA).setFill()
        r.fill()

        // 2) 巨大的纯黑 X，100% 不透明，带一圈微光描边让它在黑底上可见
        let thickness = min(r.width, r.height) * X_THICKNESS
        let inset = thickness * 0.55
        let p = NSBezierPath()
        p.move(to: NSPoint(x: inset, y: inset))
        p.line(to: NSPoint(x: r.maxX - inset, y: r.maxY - inset))
        p.move(to: NSPoint(x: inset, y: r.maxY - inset))
        p.line(to: NSPoint(x: r.maxX - inset, y: inset))
        p.lineCapStyle = .round
        p.lineJoinStyle = .round

        // 描边（外发光轮廓）
        ctx.saveGState()
        p.lineWidth = thickness + 6
        NSColor(white: 1.0, alpha: 0.16).setStroke()
        p.stroke()
        ctx.restoreGState()

        // 纯黑笔画本体
        p.lineWidth = thickness
        NSColor.black.setStroke()
        p.stroke()

        guard isPrimary else { return }

        // 3) 中心倒计时
        let secs = max(0, Int(remaining.rounded(.up)))
        let clock = String(format: "%d:%02d", secs / 60, secs % 60)
        let clockAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: min(r.width, r.height) * 0.13, weight: .bold),
            .foregroundColor: NSColor(white: 1.0, alpha: 0.92),
        ]
        let cs = clock.size(withAttributes: clockAttrs)
        clock.draw(at: NSPoint(x: r.midX - cs.width / 2, y: r.midY - cs.height / 2), withAttributes: clockAttrs)

        // 4) 休息提示
        let tip = "停下来。看远处，站起来，喝水。"
        let tipAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: min(r.width, r.height) * 0.026, weight: .medium),
            .foregroundColor: NSColor(white: 1.0, alpha: 0.45),
        ]
        let ts = tip.size(withAttributes: tipAttrs)
        tip.draw(at: NSPoint(x: r.midX - ts.width / 2, y: r.midY - cs.height / 2 - ts.height - 24),
                 withAttributes: tipAttrs)

        // 5) 极暗的解锁提示（存在但不诱人）
        let hint = typed.isEmpty ? "紧急解锁：直接键入解锁短语"
                                 : String(repeating: "•", count: min(typed.count, UNLOCK_PHRASE.count))
        let hintAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .regular),
            .foregroundColor: NSColor(white: 1.0, alpha: 0.13),
        ]
        let hs = hint.size(withAttributes: hintAttrs)
        hint.draw(at: NSPoint(x: r.midX - hs.width / 2, y: 28), withAttributes: hintAttrs)
    }
}

// borderless 窗口默认不能成为 key window，键盘事件会收不到 —— 必须重写
final class SealWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

// ===== 主控制器 =====
final class AppDelegate: NSObject, NSApplicationDelegate {
    var windows: [NSWindow] = []
    var views: [SealView] = []
    var primary: NSWindow?
    var deadline = Date().addingTimeInterval(DURATION)
    var unlocked = false
    var ticker: Timer?
    var keeper: Timer?
    var typed = ""

    func applicationDidFinishLaunching(_ n: Notification) {
        NSApp.setActivationPolicy(.regular)
        // 隐藏 Dock、菜单栏，禁用 Cmd-Tab 切换、强制退出、隐藏应用
        NSApp.presentationOptions = [
            .hideDock, .hideMenuBar, .disableProcessSwitching,
            .disableForceQuit, .disableHideApplication,
        ]

        buildWindows()

        // 屏幕数量/分辨率变化时重建
        NotificationCenter.default.addObserver(
            self, selector: #selector(buildWindows),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)

        // 每秒刷新倒计时
        ticker = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.tick()
        }
        // 每秒抢回前台，防止被切走
        keeper = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self, !self.unlocked else { return }
            NSApp.activate(ignoringOtherApps: true)
            self.primary?.makeKeyAndOrderFront(nil)
        }
        // 失效保险：无论如何到点必退
        Timer.scheduledTimer(withTimeInterval: HARD_LIMIT, repeats: false) { _ in
            NSApp.presentationOptions = []
            exit(0)
        }

        // 键盘监听：拦下所有按键，只认解锁短语
        NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] ev in
            self?.handleKey(ev)
            return nil   // 吞掉所有按键
        }

        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func buildWindows() {
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        views.removeAll()

        let main = NSScreen.main
        var keyWindow: NSWindow? = nil
        for screen in NSScreen.screens {
            let w = SealWindow(contentRect: screen.frame, styleMask: .borderless,
                               backing: .buffered, defer: false)
            w.setFrame(screen.frame, display: true)
            w.isOpaque = false
            w.backgroundColor = .clear
            w.hasShadow = false
            w.ignoresMouseEvents = false          // 吞掉鼠标点击
            w.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()) + 1)
            w.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
            w.isMovable = false

            let v = SealView(frame: NSRect(origin: .zero, size: screen.frame.size))
            v.isPrimary = (screen == main)
            w.contentView = v
            if v.isPrimary {
                w.makeKeyAndOrderFront(nil)
                keyWindow = w
            } else {
                w.orderFront(nil)
            }

            windows.append(w)
            views.append(v)
        }
        // 保证主屏窗口拿到键盘焦点（否则解锁短语收不到）
        primary = keyWindow ?? windows.first
        primary?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func tick() {
        let left = deadline.timeIntervalSinceNow
        if left <= 0 { finish(); return }
        for v in views { v.remaining = left; v.needsDisplay = true }
    }

    func handleKey(_ ev: NSEvent) {
        guard let chars = ev.charactersIgnoringModifiers?.lowercased() else { return }
        // 忽略带 Cmd/Ctrl/Option 的组合键
        if ev.modifierFlags.intersection([.command, .control, .option]).isEmpty == false { return }
        typed = (typed + chars).suffix(UNLOCK_PHRASE.count * 2).description
        for v in views { v.typed = typed; v.needsDisplay = true }
        if typed.hasSuffix(UNLOCK_PHRASE) {
            unlocked = true
            finish()
        }
    }

    func finish() {
        ticker?.invalidate()
        keeper?.invalidate()
        NSApp.presentationOptions = []
        windows.forEach { $0.orderOut(nil) }
        exit(0)
    }

    // 禁止 Cmd-Q / 关机等途径中途退出
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        return unlocked ? .terminateNow : .terminateCancel
    }
}

// ===== 启动 =====
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
