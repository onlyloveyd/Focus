import AppKit

// —— 无 GUI 的辅助入口，方便在终端里配置和调试 ——

if CommandLine.arguments.contains("--list-apps") {
    for app in NSWorkspace.shared.runningApplications
    where app.activationPolicy == .regular {
        print("\(app.bundleIdentifier ?? "-")\t\(app.localizedName ?? "?")")
    }
    exit(0)
}

if let index = CommandLine.arguments.firstIndex(of: "--add"),
   CommandLine.arguments.count > index + 1 {
    let bundleID = CommandLine.arguments[index + 1].trimmingCharacters(in: .whitespaces)
    guard !bundleID.isEmpty else {
        print("用法: Focus --add <bundle-id>")
        exit(1)
    }
    Settings.shared.addBlocked(bundleID)
    print("已添加到拦截名单: \(bundleID)")
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
