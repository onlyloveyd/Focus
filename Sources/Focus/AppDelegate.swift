import AppKit
import Combine
import SwiftUI

enum Utility {
    static func activateApp() {
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate {
    /// 供 SwiftUI（设置窗口）发起闸门请求的入口
    static var shared: AppDelegate?

    private var statusItem: NSStatusItem?
    private var enableItem: NSMenuItem!
    private var pauseItem: NSMenuItem!
    private var launchItem: NSMenuItem!
    private var styleItems: [NSMenuItem] = []

    private let overlayController = OverlayController()
    private var settingsWindow: NSWindow?
    private var logWindow: NSWindow?

    private var passes: [String: Date] = [:]      // 已说明原因的应用 -> 放行截止时间
    private var mutedUntil: [String: Date] = [:]  // 拦截处理后的短暂静默，防止事件风暴
    // 原因-时长对账：放行的 event id 待结算；会话在该应用真正回到前台时开始，
    // 前台换成别的应用时结算"实际停留时长"
    private var pendingOpenEvent: [String: Int64] = [:]
    private var openSession: (bundleID: String, eventId: Int64, startedAt: Date)?
    private var pausedUntil: Date?
    private var pauseResetWork: DispatchWorkItem?
    private var lastGoodApp: NSRunningApplication?  // 最近一个处于前台的"非拦截"应用，用于"算了"后跳回
    private var cancellables = Set<AnyCancellable>()

    private static let pauseDuration: TimeInterval = 30 * 60

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.shared = self
        setupStatusItem()

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appDidActivate(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil)

        Settings.shared.$enabled
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] enabled in
                self?.enableItem?.state = enabled ? .on : .off
                if !enabled {
                    self?.overlayController.dismiss()
                }
                self?.updateStatusIcon()
            }
            .store(in: &cancellables)

        Settings.shared.$menuIconSymbol
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateStatusIcon() }
            .store(in: &cancellables)

        Settings.shared.$copyStyle
            .receive(on: RunLoop.main)
            .sink { [weak self] style in
                self?.styleItems.forEach { $0.state = ($0.representedObject as? String) == style.rawValue ? .on : .off }
            }
            .store(in: &cancellables)

        Settings.shared.$launchAtLogin
            .receive(on: RunLoop.main)
            .sink { [weak self] on in
                self?.launchItem?.state = on ? .on : .off
            }
            .store(in: &cancellables)

        if CommandLine.arguments.contains("--test-overlay") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.presentTestOverlay()
            }
        }
    }

    // MARK: - 前台应用监控

    @objc private func appDidActivate(_ note: Notification) {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
              let bundleID = app.bundleIdentifier else { return }

        // 原因-时长对账：前台换成了别的应用，结算上一个放行会话
        if let session = openSession, session.bundleID != bundleID {
            EventLog.shared.updateDuration(
                eventId: session.eventId,
                duration: Date().timeIntervalSince(session.startedAt))
            openSession = nil
        }

        guard Settings.shared.enabled else {
            lastGoodApp = app
            return
        }
        if let until = pausedUntil, Date() < until {
            lastGoodApp = app
            return
        }

        guard Settings.shared.blockedBundles.contains(bundleID) else {
            lastGoodApp = app
            return
        }

        let now = Date()
        if let muted = mutedUntil[bundleID], now < muted { return }
        if let pass = passes[bundleID], now < pass {
            // 免拦期内首次回到前台：开始计这个"放行会话"的实际停留时长
            if let eventId = pendingOpenEvent[bundleID], openSession == nil {
                openSession = (bundleID, eventId, now)
                pendingOpenEvent[bundleID] = nil
            }
            return
        }
        guard !overlayController.isShowing else { return }

        presentOverlay(for: app, bundleID: bundleID)
    }

    private func presentOverlay(for app: NSRunningApplication, bundleID: String) {
        let target = OverlayTarget(
            bundleID: bundleID,
            appName: app.localizedName ?? bundleID,
            icon: app.icon)

        overlayController.present(
            target: target,
            copy: OverlayCopy.copy(for: Settings.shared.copyStyle),
            todayCount: EventLog.shared.todayCount(bundleID: bundleID),
            onOpen: { [weak self] reason in
                let eventId = EventLog.shared.record(bundleID: bundleID, appName: target.appName, action: .opened, reason: reason)
                self?.pendingOpenEvent[bundleID] = eventId
                self?.passes[bundleID] = Date().addingTimeInterval(Settings.shared.passInterval)
                self?.mutedUntil[bundleID] = Date().addingTimeInterval(1.5)
                self?.bringToFront(app)
            },
            onAbort: { [weak self] in
                EventLog.shared.record(bundleID: bundleID, appName: target.appName, action: .aborted, reason: "")
                self?.mutedUntil[bundleID] = Date().addingTimeInterval(1.5)
                app.hide()
                self?.bringToFront(self?.lastGoodApp)
            })
    }

    // MARK: - 拆闸闸门：关拦截 / 移出名单 / 暂停，都要走同一道冷静流程

    func requestGate(_ action: GateAction) {
        guard !overlayController.isShowing else { return }
        let copy = OverlayCopy.gateCopy(for: Settings.shared.copyStyle, action: action)
        let target = OverlayTarget(
            bundleID: action.bundleKey,
            appName: action.logName,
            icon: NSImage(systemSymbolName: "shield.lefthalf.filled", accessibilityDescription: nil))

        // 副标题"今天第 N 次想拆闸门"的计数
        let gateCountBundle: String
        if case .remove(let bundleID, _) = action {
            gateCountBundle = bundleID
        } else {
            gateCountBundle = action.bundleKey
        }

        overlayController.present(
            target: target,
            copy: copy,
            todayCount: EventLog.shared.todayGateCount(bundleID: gateCountBundle),
            onOpen: { [weak self] reason in
                switch action {
                case .disable:
                    EventLog.shared.record(bundleID: action.bundleKey, appName: action.logName, action: .disabled, reason: reason)
                    Settings.shared.enabled = false
                case .pause:
                    EventLog.shared.record(bundleID: action.bundleKey, appName: action.logName, action: .paused, reason: reason)
                    self?.performPause()
                case .remove(let bundleID, _):
                    EventLog.shared.record(bundleID: bundleID, appName: action.logName, action: .removed, reason: reason)
                    Settings.shared.blockedBundles.removeAll { $0 == bundleID }
                }
            },
            onAbort: {
                // 移出名单的收手事件要归到对应应用名下，否则汇总表会出现"同应用两行"
                let bundle: String
                if case .remove(let bundleID, _) = action {
                    bundle = bundleID
                } else {
                    bundle = action.bundleKey
                }
                EventLog.shared.record(bundleID: bundle, appName: action.logName, action: .disarmAborted, reason: "")
            })
    }

    private func bringToFront(_ app: NSRunningApplication?) {
        guard let app, !app.isTerminated, let url = app.bundleURL else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    private func presentTestOverlay() {
        let target = OverlayTarget(
            bundleID: "focus.test",
            appName: "测试应用",
            icon: NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil))
        overlayController.present(
            target: target,
            copy: OverlayCopy.copy(for: Settings.shared.copyStyle),
            todayCount: EventLog.shared.todayCount(bundleID: "focus.test"),
            onOpen: { reason in
                EventLog.shared.record(bundleID: "focus.test", appName: "测试应用", action: .opened, reason: reason)
                print("[Focus] 测试：放行，原因：\(reason)")
            },
            onAbort: {
                EventLog.shared.record(bundleID: "focus.test", appName: "测试应用", action: .aborted, reason: "")
                print("[Focus] 测试：放弃")
            })
    }

    // MARK: - 菜单栏

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let menu = NSMenu()

        enableItem = NSMenuItem(title: "拦截已启用", action: #selector(toggleEnabled), keyEquivalent: "")
        enableItem.target = self
        enableItem.state = Settings.shared.enabled ? .on : .off
        menu.addItem(enableItem)

        pauseItem = NSMenuItem(title: "暂停拦截 30 分钟", action: #selector(togglePause), keyEquivalent: "")
        pauseItem.target = self
        menu.addItem(pauseItem)

        launchItem = NSMenuItem(title: "开机自动启动", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchItem.target = self
        launchItem.state = Settings.shared.launchAtLogin ? .on : .off
        menu.addItem(launchItem)

        menu.addItem(.separator())

        // 文案风格子菜单（三选一，勾选随设置联动）
        styleItems = CopyStyle.allCases.map { style in
            let item = NSMenuItem(title: style.displayName,
                                  action: #selector(selectCopyStyle(_:)),
                                  keyEquivalent: "")
            item.target = self
            item.representedObject = style.rawValue
            return item
        }
        let styleMenu = NSMenu()
        styleMenu.title = "文案风格"
        styleItems.forEach { styleMenu.addItem($0) }
        let styleSubmenuItem = NSMenuItem()
        styleSubmenuItem.title = "文案风格"
        styleSubmenuItem.submenu = styleMenu
        styleSubmenuItem.image = menuIcon("text.quote")
        menu.addItem(styleSubmenuItem)

        let settingsItem = NSMenuItem(title: "拦截名单与设置…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        settingsItem.image = menuIcon("slider.horizontal.3")
        menu.addItem(settingsItem)

        let logItem = NSMenuItem(title: "查看记录…", action: #selector(openLog), keyEquivalent: "l")
        logItem.target = self
        logItem.image = menuIcon("clock.arrow.circlepath")
        menu.addItem(logItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "退出 Focus…", action: #selector(quitTapped), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        menu.delegate = self
        item.menu = menu
        statusItem = item
        updateStatusIcon()
    }

    /// 菜单项左侧的单色小图标，统一 16pt 保证三个入口视觉一致
    private func menuIcon(_ symbol: String) -> NSImage? {
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        image?.size = NSSize(width: 16, height: 16)
        return image
    }

    private func updateStatusIcon() {
        let isPaused = pausedUntil.map { Date() < $0 } ?? false
        // 暂停时固定用暂停符号表达状态；平时用用户选的图标，停用时整体置灰
        let symbol = isPaused ? "pause.circle" : Settings.shared.menuIconSymbol
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Focus")
            ?? NSImage(systemSymbolName: "target", accessibilityDescription: "Focus")
        statusItem?.button?.image = image
        statusItem?.button?.appearsDisabled = !Settings.shared.enabled && !isPaused
    }

    @objc private func toggleEnabled() {
        if Settings.shared.enabled {
            requestGate(.disable)   // 拆闸门要过闸；重新武装则无摩擦
        } else {
            Settings.shared.enabled = true
        }
    }

    @objc private func toggleLaunchAtLogin() {
        Settings.shared.launchAtLogin.toggle()
    }

    @objc private func togglePause() {
        let isPaused = pausedUntil.map { Date() < $0 } ?? false
        if isPaused {
            resumePause()
        } else {
            requestGate(.pause)
        }
    }

    private func performPause() {
        pausedUntil = Date().addingTimeInterval(Self.pauseDuration)
        pauseItem?.title = "恢复拦截（已暂停）"
        let work = DispatchWorkItem { [weak self] in
            self?.pausedUntil = nil
            self?.pauseItem?.title = "暂停拦截 30 分钟"
            self?.updateStatusIcon()
        }
        pauseResetWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.pauseDuration, execute: work)
        updateStatusIcon()
    }

    private func resumePause() {
        pausedUntil = nil
        pauseResetWork?.cancel()
        pauseResetWork = nil
        pauseItem?.title = "暂停拦截 30 分钟"
        updateStatusIcon()
    }

    @objc private func selectCopyStyle(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let style = CopyStyle(rawValue: raw) else { return }
        Settings.shared.copyStyle = style
    }

    @objc private func openSettings() {
        showWindow(id: \.settingsWindow, title: "拦截名单与设置", size: NSSize(width: 580, height: 580)) {
            SettingsView()
        }
    }

    @objc private func openLog() {
        showWindow(id: \.logWindow, title: "拦截记录", size: NSSize(width: 680, height: 620)) {
            LogView()
        }
    }

    private func showWindow(id: ReferenceWritableKeyPath<AppDelegate, NSWindow?>,
                            title: String, size: NSSize,
                            @ViewBuilder makeView: () -> some View) {
        let existing = self[keyPath: id]
        if let window = existing {
            Utility.activateApp()
            window.makeKeyAndOrderFront(nil)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false)
        window.title = title
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentView = NSHostingView(rootView: AnyView(makeView()))
        window.center()
        self[keyPath: id] = window
        Utility.activateApp()
        window.makeKeyAndOrderFront(nil)
    }

    /// 设置窗口每次获得焦点时，从系统回读登录项真实状态
    /// （用户可能在系统设置里增删过登录项，应用侧要跟着变）
    func windowDidBecomeKey(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              window === settingsWindow else { return }
        Settings.shared.refreshLoginItemState()
    }

    /// 焦点事件的兜底：应用整体被激活时也刷新一次
    func applicationDidBecomeActive(_ notification: Notification) {
        Settings.shared.refreshLoginItemState()
    }

    /// 菜单展开时回读登录项状态。必须同步读：状态查询很快（慢的是注册/注销），
    /// 异步读会在菜单渲染后才返回，用户看到的还是旧勾选——而内部状态可能已被
    /// 悄悄纠正，点一下就会执行与意图相反的操作
    func menuNeedsUpdate(_ menu: NSMenu) {
        let enabled = LoginItem.isEnabled
        launchItem?.state = enabled ? .on : .off
        Settings.shared.syncLoginItemDisplay(enabled)
    }

    @objc private func quitTapped() {
        // 遮罩正显示时先收起，避免 applicationShouldTerminate 拦下退出
        if overlayController.isShowing {
            overlayController.dismiss()
        }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "退出 Focus？"
        alert.informativeText = "退出后，分心拦截将完全失效。"
        alert.addButton(withTitle: "退出")
        alert.addButton(withTitle: "取消")
        Utility.activateApp()
        if alert.runModal() == .alertFirstButtonReturn {
            NSApp.terminate(nil)
        }
    }

    /// 遮罩期间拒绝 Cmd+Q 直接退出，防止"弹窗绕过"
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if overlayController.isShowing {
            overlayController.dismiss()
            return .terminateCancel
        }
        return .terminateNow
    }

    func applicationWillTerminate(_ notification: Notification) {
        // 退出前结算未完成的放行会话
        if let session = openSession {
            EventLog.shared.updateDuration(
                eventId: session.eventId,
                duration: Date().timeIntervalSince(session.startedAt))
        }
    }
}
