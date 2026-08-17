import Foundation

/// 需要过闸门的"拆闸"动作：关总开关 / 暂停 / 把应用移出名单
enum GateAction {
    case disable
    case pause
    case remove(bundleID: String, targetName: String)

    var bundleKey: String {
        switch self {
        case .disable: return "focus.gate.disable"
        case .pause: return "focus.gate.pause"
        case .remove: return "focus.gate.remove"
        }
    }

    var logName: String {
        switch self {
        case .disable: return "拦截开关"
        case .pause: return "暂停拦截"
        case .remove(_, let name): return name
        }
    }
}

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

extension OverlayCopy {
    /// 拆闸门（关闭拦截 / 移出名单 / 暂停）用的文案，与应用拦截共用同一套语气
    static func gateCopy(for style: CopyStyle, action: GateAction) -> OverlayCopy {
        switch style {
        case .standard:
            switch action {
            case .disable:
                return OverlayCopy(
                    title: { _ in "要关闭拦截吗？" },
                    subtitle: { "今天第 \($0) 次想拆闸门" },
                    placeholder: "写下你现在要关闭它的原因",
                    abortTitle: "再想想，先不关了",
                    submitCountdown: { "冷静期 \($0)s" },
                    submitTitle: "确认关闭",
                    hintCountdown: { "拆闸门前，先冷静 \($0) 秒" },
                    hintTooShort: { "写下具体原因（至少 \($0) 个字）" },
                    hintReady: "按回车确认")
            case .pause:
                return OverlayCopy(
                    title: { _ in "要暂停拦截 30 分钟吗？" },
                    subtitle: { "今天第 \($0) 次想拆闸门" },
                    placeholder: "暂停这 30 分钟，你打算做什么？",
                    abortTitle: "算了，继续守护",
                    submitCountdown: { "冷静期 \($0)s" },
                    submitTitle: "暂停 30 分钟",
                    hintCountdown: { "拆闸门前，先冷静 \($0) 秒" },
                    hintTooShort: { "写下具体原因（至少 \($0) 个字）" },
                    hintReady: "按回车确认")
            case .remove(let name):
                return OverlayCopy(
                    title: { _ in "要把「\(name)」移出名单吗？" },
                    subtitle: { "今天第 \($0) 次想拆闸门" },
                    placeholder: "为什么现在要放它出来？",
                    abortTitle: "先不移了",
                    submitCountdown: { "冷静期 \($0)s" },
                    submitTitle: "移出名单",
                    hintCountdown: { "拆闸门前，先冷静 \($0) 秒" },
                    hintTooShort: { "写下具体原因（至少 \($0) 个字）" },
                    hintReady: "按回车确认")
            }
        case .fierce:
            switch action {
            case .disable:
                return OverlayCopy(
                    title: { _ in "现在就想把它关了？" },
                    subtitle: { "今天第 \($0) 次想拆台。立规矩的是你，拆台的也是你。" },
                    placeholder: "说吧，为什么要拆自己立的闸门？",
                    abortTitle: "算了，留着它",
                    submitCountdown: { "想清楚 · \($0)s" },
                    submitTitle: "拆就拆",
                    hintCountdown: { "手别抖，先想 \($0) 秒。" },
                    hintTooShort: { "这几个字说服得了谁？（至少 \($0) 字）" },
                    hintReady: "回车，记录在案。")
            case .pause:
                return OverlayCopy(
                    title: { _ in "想放风 30 分钟？" },
                    subtitle: { "今天第 \($0) 次想拆台。立规矩的是你，拆台的也是你。" },
                    placeholder: "说说，这 30 分钟你要干什么大事？",
                    abortTitle: "算了，留着它",
                    submitCountdown: { "想清楚 · \($0)s" },
                    submitTitle: "放风 30 分钟",
                    hintCountdown: { "手别抖，先想 \($0) 秒。" },
                    hintTooShort: { "这几个字说服得了谁？（至少 \($0) 字）" },
                    hintReady: "回车，记录在案。")
            case .remove(let name):
                return OverlayCopy(
                    title: { _ in "要把「\(name)」放出来？" },
                    subtitle: { "今天第 \($0) 次想拆台。立规矩的是你，拆台的也是你。" },
                    placeholder: "它哪里冤枉你了，说说？",
                    abortTitle: "算了，留着它",
                    submitCountdown: { "想清楚 · \($0)s" },
                    submitTitle: "放它出来",
                    hintCountdown: { "手别抖，先想 \($0) 秒。" },
                    hintTooShort: { "这几个字说服得了谁？（至少 \($0) 字）" },
                    hintReady: "回车，记录在案。")
            }
        case .gentle:
            switch action {
            case .disable:
                return OverlayCopy(
                    title: { _ in "想先关掉它休息一下？" },
                    subtitle: { "今天第 \($0) 次想关掉它，这很正常" },
                    placeholder: "如果愿意，说说你现在的状态～",
                    abortTitle: "先留着吧",
                    submitCountdown: { "深呼吸 · \($0)s" },
                    submitTitle: "嗯，关一会儿",
                    hintCountdown: { "不急，先陪自己待 \($0) 秒" },
                    hintTooShort: { "轻轻写下你的原因（至少 \($0) 字）" },
                    hintReady: "准备好了，按回车就好。")
            case .pause:
                return OverlayCopy(
                    title: { _ in "想休息 30 分钟吗？" },
                    subtitle: { "今天第 \($0) 次想关掉它，这很正常" },
                    placeholder: "休息的时候想做什么，愿意的话说说～",
                    abortTitle: "先留着吧",
                    submitCountdown: { "深呼吸 · \($0)s" },
                    submitTitle: "好，休息一下",
                    hintCountdown: { "不急，先陪自己待 \($0) 秒" },
                    hintTooShort: { "轻轻写下你的原因（至少 \($0) 字）" },
                    hintReady: "准备好了，按回车就好。")
            case .remove(let name):
                return OverlayCopy(
                    title: { _ in "想让「\(name)」自由一会儿？" },
                    subtitle: { "今天第 \($0) 次想关掉它，这很正常" },
                    placeholder: "如果愿意，说说为什么现在需要它～",
                    abortTitle: "先留着吧",
                    submitCountdown: { "深呼吸 · \($0)s" },
                    submitTitle: "嗯，移出去",
                    hintCountdown: { "不急，先陪自己待 \($0) 秒" },
                    hintTooShort: { "轻轻写下你的原因（至少 \($0) 字）" },
                    hintReady: "准备好了，按回车就好。")
            }
        }
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
