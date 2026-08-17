import Foundation
import Combine

/// 全局配置：拦截名单 + 摩擦参数，持久化到 UserDefaults。
final class Settings: ObservableObject {
    static let shared = Settings()

    private let defaults = UserDefaults.standard

    @Published var enabled: Bool { didSet { defaults.set(enabled, forKey: "enabled") } }
    @Published var blockedBundles: [String] { didSet { defaults.set(blockedBundles, forKey: "blockedBundles") } }
    @Published var delaySeconds: Int { didSet { defaults.set(delaySeconds, forKey: "delaySeconds") } }
    @Published var passMinutes: Int { didSet { defaults.set(passMinutes, forKey: "passMinutes") } }
    @Published var minReasonLength: Int { didSet { defaults.set(minReasonLength, forKey: "minReasonLength") } }
    @Published var menuIconSymbol: String { didSet { defaults.set(menuIconSymbol, forKey: "menuIconSymbol") } }
    @Published var copyStyle: CopyStyle {
        didSet { defaults.set(copyStyle.rawValue, forKey: "copyStyle") }
    }
    /// 开机自启：真值来自系统登录项（SMAppService），这里只做 UI 绑定。
    /// 注册是一次可能很慢的系统 XPC 调用，必须放后台线程，否则主线程卡死。
    private var syncingLoginItem = false
    @Published var launchAtLogin: Bool {
        didSet {
            guard !syncingLoginItem else { return }
            let target = launchAtLogin
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                LoginItem.setEnabled(target)
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.syncingLoginItem = true
                    self.launchAtLogin = LoginItem.isEnabled
                    self.syncingLoginItem = false
                }
            }
        }
    }

    /// 菜单栏图标的候选（都是 SF Symbols，macOS 13 可用）
    static let iconChoices = [
        "target",             // 靶心
        "eye.fill",           // 眼睛
        "camera.macro",       // 光圈
        "flame.fill",         // 火焰
        "hourglass",          // 沙漏
        "brain.head.profile", // 大脑
    ]

    private init() {
        // 首次运行：默认只拦微信，其余在界面里按需添加
        if defaults.object(forKey: "blockedBundles") == nil {
            defaults.set([
                "com.tencent.xinWeChat",
            ], forKey: "blockedBundles")
            defaults.set(true, forKey: "enabled")
        }
        enabled = defaults.bool(forKey: "enabled")
        blockedBundles = defaults.stringArray(forKey: "blockedBundles") ?? []
        delaySeconds = defaults.object(forKey: "delaySeconds") as? Int ?? 5
        passMinutes = defaults.object(forKey: "passMinutes") as? Int ?? 5
        minReasonLength = defaults.object(forKey: "minReasonLength") as? Int ?? 4
        menuIconSymbol = defaults.string(forKey: "menuIconSymbol") ?? "target"
        copyStyle = CopyStyle(rawValue: defaults.string(forKey: "copyStyle") ?? "") ?? .standard
        launchAtLogin = LoginItem.isEnabled
    }

    /// 从系统回读登录项状态。系统没有登录项变化的通知，只能主动刷新；
    /// 典型时机：设置窗口获得焦点、菜单栏菜单展开、应用被激活。
    func refreshLoginItemState() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let enabled = LoginItem.isEnabled
            DispatchQueue.main.async {
                guard let self, self.launchAtLogin != enabled else { return }
                self.syncingLoginItem = true
                self.launchAtLogin = enabled
                self.syncingLoginItem = false
            }
        }
    }

    /// 菜单展开等"这一刻就必须是真值"的场景：同步校正内部状态
    /// （异步路径会在显示之后才回来，用户看到的仍是旧状态）
    func syncLoginItemDisplay(_ enabled: Bool) {
        guard launchAtLogin != enabled else { return }
        syncingLoginItem = true
        launchAtLogin = enabled
        syncingLoginItem = false
    }

    func addBlocked(_ bundleID: String) {
        let id = bundleID.trimmingCharacters(in: .whitespaces)
        guard !id.isEmpty, !blockedBundles.contains(id) else { return }
        blockedBundles.append(id)
    }

    var passInterval: TimeInterval { TimeInterval(passMinutes) * 60 }
}
