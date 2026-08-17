import Foundation
import ServiceManagement

/// 开机自启，真值由系统的登录项状态决定（不落 UserDefaults，避免双份状态）。
enum LoginItem {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// 返回是否设置成功。注册/注销是慢速系统调用，调用方应在后台线程执行；
    /// 状态查询（isEnabled）则很快，可同步调用（如菜单展开时）。
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return true
        } catch {
            print("[Focus] 登录项设置失败: \(error.localizedDescription)")
            return false
        }
    }
}
