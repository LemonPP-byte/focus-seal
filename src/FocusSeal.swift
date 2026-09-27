// FocusSeal — 整点强制休息封条
// 在整点 :00 和 :30 各封屏 5 分钟，一个巨大的黑色 X 横铺全屏。
// 倒计时走完不会自动解封：必须写下下一段的目标并回车，才放行（目标写进 goal.txt，刘海胶囊显示）。
// 紧急解锁：倒计时中直接键入解锁短语；写目标阶段在输入框里键入解锁短语并回车。
// 编译：swiftc -O -o bin/focus-seal FocusSeal.swift -framework Cocoa

import Cocoa

// ===== 可调参数 =====
let UNLOCK_PHRASE = "overridebreak"   // 强力解锁短语，键入即解封
let SCRIM_ALPHA: CGFloat = 0.93       // X 以外区域的遮黑程度
let X_THICKNESS: CGFloat = 0.13       // X 笔画粗细，占屏幕短边比例
let HARD_LIMIT: TimeInterval = 1500   // 失效保险：超过这个秒数无条件退出（要给写目标阶段留足时间，但赶在下一次封屏前）
let MIN_GOAL_CHARS = 2                // 目标至少几个字
let GOAL_FILE = NSString(string: "~/.focus-seal/goal.txt").expandingTildeInPath

func readGoal() -> String {
    ((try? String(contentsOfFile: GOAL_FILE, encoding: .utf8)) ?? "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

func logLine(_ msg: String) {
    let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd HH:mm:ss"
    FileHandle.standardError.write("[\(f.string(from: Date()))] \(msg)\n".data(using: .utf8)!)
}

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
    var goalPhase = false   // 倒计时走完，进入写目标阶段

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

        if goalPhase { drawGoalPrompt(r); return }

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

    // 写目标阶段：输入框本身是子视图，这里只画上下的文字
    func drawGoalPrompt(_ r: NSRect) {
        let title = "休息结束。下一段做什么？"
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: min(r.width, r.height) * 0.04, weight: .semibold),
            .foregroundColor: NSColor(white: 1.0, alpha: 0.92),
        ]
        let ts = title.size(withAttributes: titleAttrs)
        title.draw(at: NSPoint(x: r.midX - ts.width / 2, y: r.midY + 56), withAttributes: titleAttrs)

        let sub = "写一件这 25 分钟里能做完的具体的事，回车进入下一段"
        let subAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 15, weight: .regular),
            .foregroundColor: NSColor(white: 1.0, alpha: 0.42),
        ]
        let ss = sub.size(withAttributes: subAttrs)
        sub.draw(at: NSPoint(x: r.midX - ss.width / 2, y: r.midY - 28 - 20 - ss.height), withAttributes: subAttrs)

        let hint = "紧急解锁：在输入框里键入解锁短语并回车"
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
    var goalPhase = false
    var field: NSTextField?
    var fieldBox: NSView?

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
            // 只在真被切走时才抢，免得打断输入法的候选框
            if !NSApp.isActive { NSApp.activate(ignoringOtherApps: true) }
            if self.primary?.isKeyWindow == false { self.primary?.makeKeyAndOrderFront(nil) }
        }
        // 失效保险：无论如何到点必退
        Timer.scheduledTimer(withTimeInterval: HARD_LIMIT, repeats: false) { _ in
            NSApp.presentationOptions = []
            exit(0)
        }

        // 键盘监听：倒计时阶段拦下所有按键，只认解锁短语；
        // 写目标阶段放行给输入框（含输入法），但仍吞掉 Cmd 组合键防止 Cmd-Q / Cmd-W
        NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] ev in
            guard let self else { return nil }
            if self.goalPhase {
                return ev.modifierFlags.contains(.command) ? nil : ev
            }
            self.handleKey(ev)
            return nil
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
        if goalPhase { applyGoalPhase() }
    }

    func tick() {
        let left = deadline.timeIntervalSinceNow
        if left <= 0 { enterGoalPhase(); return }
        for v in views { v.remaining = left; v.needsDisplay = true }
    }

    // ===== 写目标阶段 =====
    func enterGoalPhase() {
        ticker?.invalidate()
        goalPhase = true
        logLine("休息结束，等待写目标")
        applyGoalPhase()
    }

    func applyGoalPhase() {
        // 屏蔽级窗口会盖住输入法候选框，降到 floating：仍高于所有普通窗口，
        // 加上禁止切换应用、隐藏 Dock/菜单栏，其他应用照样够不着
        for w in windows { w.level = .floating }
        for v in views { v.goalPhase = true; v.needsDisplay = true }
        installGoalField()
    }

    func installGoalField() {
        guard let win = primary, let v = win.contentView else { return }
        let draft = field?.stringValue ?? ""     // 插拔显示器重建时保留已输入的内容
        fieldBox?.removeFromSuperview()

        let W = min(640, v.bounds.width - 80), H: CGFloat = 56
        let box = NSView(frame: NSRect(x: v.bounds.midX - W / 2, y: v.bounds.midY - H / 2, width: W, height: H))
        box.wantsLayer = true
        box.layer?.backgroundColor = NSColor(white: 0.1, alpha: 1).cgColor
        box.layer?.cornerRadius = 14
        box.layer?.borderWidth = 1
        box.layer?.borderColor = NSColor(white: 1, alpha: 0.18).cgColor

        let f = NSTextField(string: draft)
        f.isBordered = false
        f.drawsBackground = false
        f.focusRingType = .none
        f.font = .systemFont(ofSize: 24, weight: .medium)
        f.textColor = .white
        f.alignment = .center
        f.usesSingleLineMode = true
        f.cell?.wraps = false
        f.cell?.isScrollable = true
        f.cell?.sendsActionOnEndEditing = false
        let prev = readGoal()
        // 占位文字不继承输入框的 alignment，得单独给段落样式才会居中
        let centered = NSMutableParagraphStyle()
        centered.alignment = .center
        centered.lineBreakMode = .byTruncatingTail
        f.placeholderAttributedString = NSAttributedString(
            string: prev.isEmpty ? "比如：写完竞品分析第一部分" : "上一段：\(prev)",
            attributes: [.foregroundColor: NSColor(white: 1, alpha: 0.28), .font: f.font!,
                         .paragraphStyle: centered])
        f.target = self
        f.action = #selector(submitGoal)
        let fh = f.cell!.cellSize.height
        f.frame = NSRect(x: 20, y: (H - fh) / 2, width: W - 40, height: fh)

        box.addSubview(f)
        v.addSubview(box)
        field = f
        fieldBox = box
        win.makeKeyAndOrderFront(nil)
        win.makeFirstResponder(f)
    }

    @objc func submitGoal() {
        let g = (field?.stringValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if g.lowercased() == UNLOCK_PHRASE {
            logLine("紧急解锁，未写目标")
            unlocked = true
            finish()
            return
        }
        guard g.count >= MIN_GOAL_CHARS else { shake(); return }
        try? (g + "\n").write(toFile: GOAL_FILE, atomically: true, encoding: .utf8)
        logLine("目标：\(g)")
        unlocked = true
        finish()
    }

    // 空着回车：输入框左右抖一下
    func shake() {
        guard let layer = fieldBox?.layer else { return }
        let a = CAKeyframeAnimation(keyPath: "transform.translation.x")
        a.values = [0, -14, 12, -8, 6, -3, 0]
        a.duration = 0.4
        layer.add(a, forKey: "shake")
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
