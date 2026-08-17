import SwiftUI
import Charts

private struct ChartPoint: Identifiable {
    let id = UUID()
    let date: Date
    let kind: String
    let count: Int
}

struct LogView: View {
    @State private var events: [LogEvent] = []
    @State private var summaries: [AppSummary] = []
    @State private var daily: [DailyCount] = []
    @State private var selectedBundle = ""
    @State private var listMode = 0   // 0 按应用汇总，1 拦截明细

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm:ss"
        return formatter
    }()

    private var chartPoints: [ChartPoint] {
        daily.flatMap { day in
            [
                ChartPoint(date: day.date, kind: "打开了", count: day.opened),
                ChartPoint(date: day.date, kind: "忍住了", count: day.aborted),
            ]
        }
    }

    var body: some View {
        if events.isEmpty && summaries.isEmpty {
            VStack(spacing: 10) {
                Spacer()
                Text("还没有记录")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text("下一次拦截弹窗出现时，你的选择和原因会记录在这里。")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .frame(minWidth: 640, minHeight: 560)
            .onAppear { reload() }
        } else {
            VStack(spacing: 0) {
                chartSection
                    .padding()
                Divider()
                listSection
            }
            .frame(minWidth: 680, minHeight: 640)
            .onAppear { reload() }
            .onChange(of: selectedBundle) { _ in reload() }
        }
    }

    // MARK: - 上：趋势图

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("最近 14 天")
                    .font(.headline)
                Spacer()
                Picker("", selection: $selectedBundle) {
                    Text("全部应用").tag("")
                    ForEach(summaries) { summary in
                        Text(summary.appName).tag(summary.bundleID)
                    }
                }
                .labelsHidden()
                .frame(width: 170)
                Button {
                    reload()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("刷新数据")
            }

            let totalOpened = daily.map(\.opened).reduce(0, +)
            let totalAborted = daily.map(\.aborted).reduce(0, +)
            let total = totalOpened + totalAborted
            Text("打开 \(totalOpened) 次 · 忍住 \(totalAborted) 次"
                 + (total > 0 ? " · 忍住率 \(totalAborted * 100 / total)%" : ""))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Chart(chartPoints) { point in
                BarMark(
                    x: .value("日期", point.date, unit: .day),
                    y: .value("次数", point.count)
                )
                .foregroundStyle(by: .value("类型", point.kind))
            }
            .chartForegroundStyleScale(["打开了": .orange, "忍住了": .green])
            .chartLegend(position: .top, spacing: 14)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 2)) {
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month().day())
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4))
            }
            .frame(height: 170)
        }
    }

    // MARK: - 下：详情列表（两个维度二选一）

    private var listSection: some View {
        VStack(spacing: 0) {
            Picker("", selection: $listMode) {
                Text("按应用汇总").tag(0)
                Text("拦截明细").tag(1)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 240)
            .padding(.vertical, 8)

            if listMode == 0 {
                summaryList
            } else {
                eventList
            }
        }
    }

    private var summaryList: some View {
        Table(summaries) {
            TableColumn("应用") { summary in
                Text(summary.appName).bold()
            }
            TableColumn("打开") { summary in
                Text("\(summary.opened)").foregroundStyle(.orange)
            }
            .width(60)
            TableColumn("忍住") { summary in
                Text("\(summary.aborted)").foregroundStyle(.green)
            }
            .width(60)
            TableColumn("忍住率") { summary in
                let total = summary.opened + summary.aborted
                Text(total > 0 ? "\(summary.aborted * 100 / total)%" : "—")
                    .foregroundStyle(.secondary)
            }
            .width(70)
        }
    }

    private var eventList: some View {
        Table(events) {
            TableColumn("时间") { event in
                Text(Self.timeFormatter.string(from: event.date))
                    .foregroundStyle(.secondary)
            }
            .width(115)
            TableColumn("应用") { event in
                Text(event.appName)
            }
            .width(110)
            TableColumn("结果") { event in
                let badge = Self.badge(for: event.action)
                Text(badge.text).foregroundStyle(badge.color)
            }
            .width(65)
            TableColumn("原因") { event in
                VStack(alignment: .leading, spacing: 1) {
                    Text(event.reason.isEmpty ? "—" : event.reason)
                        .italic()
                    if event.action == .opened, let duration = event.duration {
                        Text("实际停留 \(Self.durationText(duration))")
                            .foregroundStyle(.secondary.opacity(0.7))
                    }
                }
            }
        }
    }

    private static func badge(for action: LogAction) -> (text: String, color: Color) {
        switch action {
        case .opened: return ("打开了", .orange)
        case .aborted: return ("忍住了", .green)
        case .disabled: return ("关掉了", .red)
        case .paused: return ("暂停了", .orange)
        case .removed: return ("移出了", .orange)
        case .disarmAborted: return ("没拆成", .green)
        }
    }

    private static func durationText(_ seconds: TimeInterval) -> String {
        if seconds < 60 { return "\(Int(seconds)) 秒" }
        if seconds < 3600 { return String(format: "%.0f 分钟", seconds / 60) }
        return String(format: "%.1f 小时", seconds / 3600)
    }

    private func reload() {
        events = EventLog.shared.recentEvents(limit: 200)
        summaries = EventLog.shared.summary(days: 7)
        daily = EventLog.shared.dailyCounts(
            days: 14,
            bundleID: selectedBundle.isEmpty ? nil : selectedBundle)
    }
}
