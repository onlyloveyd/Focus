import AppKit
import SwiftUI

/// 根据 Bundle ID 解析应用名称 / 图标（带缓存）。
enum AppInfo {
    private static var nameCache: [String: String] = [:]

    static func appURL(for bundleID: String) -> URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
    }

    static func name(for bundleID: String) -> String {
        if let cached = nameCache[bundleID] { return cached }
        let name = appURL(for: bundleID)
            .flatMap { Bundle(url: $0)?.object(forInfoDictionaryKey: kCFBundleNameKey as String) as? String }
            ?? bundleID
        nameCache[bundleID] = name
        return name
    }

    static func icon(for bundleID: String) -> NSImage? {
        appURL(for: bundleID).map { NSWorkspace.shared.icon(forFile: $0.path) }
    }
}

struct SettingsView: View {
    @ObservedObject private var settings = Settings.shared
    @State private var selection: String?
    @State private var showPicker = false
    @State private var manualBundleID = ""

    var body: some View {
        Form {
            Section(header: Text("拦截名单")) {
                List(selection: $selection) {
                    ForEach(settings.blockedBundles, id: \.self) { bundleID in
                        HStack(spacing: 10) {
                            if let icon = AppInfo.icon(for: bundleID) {
                                Image(nsImage: icon)
                                    .frame(width: 28, height: 28)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(AppInfo.name(for: bundleID))
                                Text(bundleID)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 3)
                    }
                    .onDelete { offsets in
                        settings.blockedBundles.remove(atOffsets: offsets)
                    }
                }
                .frame(minHeight: 220)
                .border(.quaternary)

                HStack(spacing: 8) {
                    Button {
                        showPicker = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    Button {
                        if let id = selection {
                            settings.blockedBundles.removeAll { $0 == id }
                            selection = nil
                        }
                    } label: {
                        Image(systemName: "minus")
                    }
                    .disabled(selection == nil)

                    Spacer()

                    TextField("手动输入 Bundle ID", text: $manualBundleID)
                        .frame(width: 220)
                    Button("添加") {
                        settings.addBlocked(manualBundleID)
                        manualBundleID = ""
                    }
                    .disabled(manualBundleID.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            Section(header: Text("摩擦参数")) {
                Stepper("冷静期：\(settings.delaySeconds) 秒", value: $settings.delaySeconds, in: 0...60)
                Stepper("放行时长：\(settings.passMinutes) 分钟", value: $settings.passMinutes, in: 1...120)
                Stepper("原因最少字数：\(settings.minReasonLength) 字", value: $settings.minReasonLength, in: 0...30)
                Text("放行时长 = 说明原因后，该应用在多少分钟内不会再被拦截。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Section(header: Text("文案风格")) {
                Picker("语气", selection: $settings.copyStyle) {
                    Text("标准").tag(CopyStyle.standard)
                    Text("凶狠").tag(CopyStyle.fierce)
                    Text("温柔治愈").tag(CopyStyle.gentle)
                }
                .pickerStyle(.radioGroup)
                Text(settings.copyStyle.sample)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Section(header: Text("菜单栏图标")) {
                HStack(spacing: 14) {
                    ForEach(Settings.iconChoices, id: \.self) { symbol in
                        Button {
                            settings.menuIconSymbol = symbol
                        } label: {
                            Image(systemName: symbol)
                                .font(.system(size: 16, weight: .medium))
                                .frame(width: 34, height: 28)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(settings.menuIconSymbol == symbol
                                              ? Color.accentColor.opacity(0.35)
                                              : Color.clear)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Section(header: Text("状态")) {
                Toggle("启用拦截", isOn: $settings.enabled)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 560, minHeight: 560)
        .sheet(isPresented: $showPicker) {
            RunningAppPicker { settings.addBlocked($0) }
        }
    }
}

struct RunningAppPicker: View {
    var onPick: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var apps: [NSRunningApplication] {
        let all = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && !($0.bundleIdentifier ?? "").isEmpty }
        let sorted = all.sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
        guard !query.isEmpty else { return sorted }
        let q = query.lowercased()
        return sorted.filter {
            ($0.localizedName ?? "").lowercased().contains(q)
                || ($0.bundleIdentifier ?? "").lowercased().contains(q)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("从正在运行的应用中选择")
                .font(.headline)
                .padding()
            TextField("搜索名称或 Bundle ID", text: $query)
                .textFieldStyle(.roundedBorder)
                .padding([.horizontal, .bottom])
            List(apps, id: \.processIdentifier) { app in
                Button {
                    if let bundleID = app.bundleIdentifier {
                        onPick(bundleID)
                    }
                    dismiss()
                } label: {
                    HStack(spacing: 10) {
                        if let icon = app.icon {
                            Image(nsImage: icon)
                                .frame(width: 28, height: 28)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(app.localizedName ?? "?")
                            Text(app.bundleIdentifier ?? "")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .frame(minWidth: 440, minHeight: 480)
    }
}
