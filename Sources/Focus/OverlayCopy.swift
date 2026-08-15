import Foundation

/// 弹窗文案风格：标准 / 凶狠 / 温柔治愈
enum CopyStyle: String, CaseIterable, Identifiable {
    case standard
    case fierce
    case gentle

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .standard: return "标准"
        case .fierce: return "凶狠"
        case .gentle: return "温柔治愈"
        }
    }

    /// 设置界面里的示例句，让人不用触发弹窗也能预览语气
    var sample: String {
        let copy = OverlayCopy.copy(for: self)
        return "预览：" + copy.subtitle(3)
    }
}

/// 一套完整的遮罩文案。N 类参数以闭包传入（应用名、次数、秒数、最少字数）。
struct OverlayCopy {
    let title: (String) -> String
    let subtitle: (Int) -> String
    let placeholder: String
    let abortTitle: String
    let submitCountdown: (Int) -> String
    let submitTitle: String
    let hintCountdown: (Int) -> String
    let hintTooShort: (Int) -> String
    let hintReady: String

    static func copy(for style: CopyStyle) -> OverlayCopy {
        switch style {
        case .standard:
            return OverlayCopy(
                title: { "要打开「\($0)」吗？" },
                subtitle: { "今天第 \($0) 次想打开它" },
                placeholder: "我要做什么？例如：回复张三的消息",
                abortTitle: "算了，回去工作",
                submitCountdown: { "冷静期 \($0)s" },
                submitTitle: "继续打开",
                hintCountdown: { "先想清楚为什么要点开它 · \($0) 秒后可继续" },
                hintTooShort: { "写下具体目的（至少 \($0) 个字）" },
                hintReady: "按回车继续")
        case .fierce:
            return OverlayCopy(
                title: { "又要点开「\($0)」？" },
                subtitle: { "今天第 \($0) 次，“就看一眼”不算理由" },
                placeholder: "一句话说清楚：你到底要干什么？",
                abortTitle: "滚回去干活",
                submitCountdown: { "想清楚 · \($0)s" },
                submitTitle: "理由成立，放行",
                hintCountdown: { "真的必须现在点吗？想 \($0) 秒。" },
                hintTooShort: { "这几个字，你自己信吗？（至少 \($0) 字）" },
                hintReady: "回车放行，记录在案。")
        case .gentle:
            return OverlayCopy(
                title: { "想看看「\($0)」了吗？" },
                subtitle: { "今天第 \($0) 次想点开它，这很正常" },
                placeholder: "如果愿意，说说你想去做什么～比如回一条消息",
                abortTitle: "先不看了，回去吧",
                submitCountdown: { "深呼吸 · \($0)s" },
                submitTitle: "嗯，确实需要",
                hintCountdown: { "不着急，先陪自己待 \($0) 秒" },
                hintTooShort: { "轻轻写下你的理由（至少 \($0) 字）" },
                hintReady: "准备好了，按回车就好。")
        }
    }
}
