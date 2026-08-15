import AppKit
import SwiftUI

struct OverlayTarget {
    let bundleID: String
    let appName: String
    let icon: NSImage?
}

/// 遮罩面板：无边框、置于所有空间之上（含全屏），半透明深色底。
final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { true }

    init(screen: NSScreen, content: NSView) {
        super.init(contentRect: screen.frame,
                   styleMask: [.borderless],
                   backing: .buffered,
                   defer: false)
        contentView = content
        backgroundColor = NSColor.black.withAlphaComponent(0.92)
        // 锁定深色外观，避免面板内控件首次渲染时按浅色主题取色（文字发暗）
        appearance = NSAppearance(named: .darkAqua)
        isOpaque = false
        hasShadow = false
        level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        ignoresMouseEvents = false
    }
}

/// 遮罩的视图模型：倒计时、原因校验、回调。
final class OverlayModel: ObservableObject {
    let appName: String
    let icon: NSImage?
    let minReasonLength: Int
    let copy: OverlayCopy
    let onOpen: (String) -> Void
    let onAbort: () -> Void

    @Published var reason = ""
    @Published var remaining = 0
    @Published var todayCount = 0

    private let delaySeconds: Int
    private var timer: Timer?

    init(appName: String,
         icon: NSImage?,
         delaySeconds: Int,
         minReasonLength: Int,
         copy: OverlayCopy,
         onOpen: @escaping (String) -> Void,
         onAbort: @escaping () -> Void) {
        self.appName = appName
        self.icon = icon
        self.delaySeconds = max(0, delaySeconds)
        self.minReasonLength = max(0, minReasonLength)
        self.copy = copy
        self.onOpen = onOpen
        self.onAbort = onAbort
    }

    var titleText: String { copy.title(appName) }
    var subtitleText: String { copy.subtitle(todayCount) }

    var trimmedReason: String { reason.trimmingCharacters(in: .whitespacesAndNewlines) }

    var canSubmit: Bool { remaining == 0 && trimmedReason.count >= minReasonLength }

    var hint: String {
        if remaining > 0 {
            return copy.hintCountdown(remaining)
        }
        if trimmedReason.count < minReasonLength {
            return copy.hintTooShort(minReasonLength)
        }
        return copy.hintReady
    }

    func start() {
        remaining = delaySeconds
        guard delaySeconds > 0 else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            self.remaining = max(0, self.remaining - 1)
            if self.remaining == 0 {
                timer.invalidate()
                self.timer = nil
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func submitTapped() {
        guard canSubmit else { return }
        stop()
        onOpen(trimmedReason)
    }

    func abortTapped() {
        stop()
        onAbort()
    }
}

/// 负责遮罩的生命周期：每个屏幕一块遮罩，鼠标所在屏的面板接管键盘。
final class OverlayController {
    private var panels: [OverlayPanel] = []
    private var model: OverlayModel?

    var isShowing: Bool { !panels.isEmpty }

    func present(target: OverlayTarget,
                 todayCount: Int,
                 onOpen: @escaping (String) -> Void,
                 onAbort: @escaping () -> Void) {
        dismiss()

        let model = OverlayModel(
            appName: target.appName,
            icon: target.icon,
            delaySeconds: Settings.shared.delaySeconds,
            minReasonLength: Settings.shared.minReasonLength,
            copy: OverlayCopy.copy(for: Settings.shared.copyStyle),
            onOpen: { [weak self] reason in
                self?.dismiss()
                onOpen(reason)
            },
            onAbort: { [weak self] in
                self?.dismiss()
                onAbort()
            })
        model.todayCount = todayCount
        self.model = model

        let view = OverlayView(model: model)
        for screen in NSScreen.screens {
            panels.append(OverlayPanel(screen: screen, content: NSHostingView(rootView: view)))
        }

        Utility.activateApp()
        let keyScreen = NSScreen.main ?? NSScreen.screens.first
        let keyPanel = panels.first(where: { $0.frame == keyScreen?.frame }) ?? panels.first
        keyPanel?.makeKeyAndOrderFront(nil)
        for panel in panels where panel !== keyPanel {
            panel.orderFrontRegardless()
        }
        model.start()
    }

    func dismiss() {
        model?.stop()
        model = nil
        panels.forEach { $0.orderOut(nil) }
        panels.removeAll()
    }
}
