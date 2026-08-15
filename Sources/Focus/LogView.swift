import SwiftUI

struct LogView: View {
    @State private var events: [LogEvent] = []
    @State private var summaries: [AppSummary] = []

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm:ss"
        return formatter
    }()

    var body: some View {
        VStack(spacing: 0) {
            if summaries.isEmpty && events.isEmpty {
                Spacer()
                Text("还没有记录")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text("下一次拦截弹窗出现时，你的选择和原因会记录在这里。")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("最近 7 天汇总").font(.headline)
                        Spacer()
                        Button("刷新") { reload() }
                    }
                    ForEach(summaries) { summary in
                        HStack {
                            Text(summary.appName).bold()
                            Spacer()
                            Text("打开 \(summary.opened) 次 · 忍住 \(summary.aborted) 次")
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 5)
                        .padding(.horizontal, 10)
                        .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary.opacity(0.4)))
                    }
                }
                .padding()
                .frame(maxHeight: 260)

                Divider()

                List(events) { event in
                    HStack(alignment: .top, spacing: 10) {
                        Text(Self.timeFormatter.string(from: event.date))
                            .foregroundStyle(.secondary)
                            .frame(width: 96, alignment: .leading)
                        Text(event.appName)
                            .frame(width: 110, alignment: .leading)
                        Text(event.action == .aborted ? "忍住了" : "打开了")
                            .foregroundStyle(event.action == .aborted ? .green : .orange)
                            .frame(width: 52, alignment: .leading)
                        Text(event.reason.isEmpty ? "—" : event.reason)
                            .italic()
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                        Spacer(minLength: 0)
                    }
                    .font(.system(size: 12))
                }
                .listStyle(.plain)
            }
        }
        .frame(minWidth: 640, minHeight: 560)
        .onAppear { reload() }
    }

    private func reload() {
        events = EventLog.shared.recentEvents(limit: 200)
        summaries = EventLog.shared.summary(days: 7)
    }
}
