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
        // 首次运行：预填用户自己点名的几个常见分心应用，之后可在界面里改
        if defaults.object(forKey: "blockedBundles") == nil {
            defaults.set([
                "com.tencent.xinWeChat",
                "com.google.Chrome",
                "com.apple.Safari",
                "com.kingsoft.wpsoffice.mac",
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
    }

    func addBlocked(_ bundleID: String) {
        let id = bundleID.trimmingCharacters(in: .whitespaces)
        guard !id.isEmpty, !blockedBundles.contains(id) else { return }
        blockedBundles.append(id)
    }

    var passInterval: TimeInterval { TimeInterval(passMinutes) * 60 }
}
