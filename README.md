# Focus — 用"输入原因"阻断无意识的应用切换

一个 macOS 菜单栏应用。当你切到名单里的分心应用（微信、浏览器、WPS……）时，
全屏深色遮罩会盖住它，要求你：

1. 等过**冷静期**（默认 5 秒）；
2. 写下**具体原因**（默认至少 4 个字，比如"回复张三的消息"）；
3. 然后选择「继续打开」或「算了，回去工作」。

每一次选择都会记入本地 SQLite，在「查看记录」里可以看到每场比赛你和冲动谁赢了。

## 工作原理（方案 A：前台监控 + 遮罩）

监听 `NSWorkspace.didActivateApplicationNotification`。名单内的应用一进入前台，
就在每个屏幕上放置一块 `CGShieldingWindowLevel` 级别的无边框 `NSPanel`
（加入所有 Space、覆盖全屏应用），输入原因后放行并给予默认 5 分钟的"免拦期"。
不需要任何特殊权限（无辅助功能、无内核/系统扩展）。

## 构建与运行

```bash
swift build -c release
.build/release/Focus &        # 菜单栏出现 🔭 图标
```

打包成 .app 并设置开机启动：

```bash
./Scripts/make-app.sh         # 生成 Focus.app，按提示拖入 /Applications 并加到登录项
```

`Focus.app` 的应用图标（Finder、登录项里显示的）由 `Scripts/generate-icon.swift`
矢量绘制并自动嵌入（深色底 + 青色靶心），无需任何设计素材；想换风格直接改脚本重跑。

## 试用 / 调试

```bash
.build/debug/Focus --test-overlay   # 启动 1 秒后弹出一个测试遮罩，不用真的打开微信
.build/debug/Focus --list-apps      # 列出当前运行应用的 Bundle ID
.build/debug/Focus --add <bundle-id>  # 命令行加名单
```

首次运行已预填：微信、Chrome、Safari、WPS。名单可在菜单栏 →「拦截名单与设置」里
从正在运行的应用中点选添加，或手动输入 Bundle ID。

## 参数（设置窗口里可调）

| 参数 | 默认 | 说明 |
|---|---|---|
| 冷静期 | 5 秒 | 「继续打开」按钮在倒计时结束前不可点 |
| 放行时长 | 5 分钟 | 说明原因后该应用在此时间内不再被拦 |
| 原因最少字数 | 4 字 | 防止随手乱敲一两个字 |

菜单栏还提供「暂停拦截 30 分钟」；退出时会弹确认框，且遮罩显示期间 Cmd+Q 会被拒绝
（防止弹窗绕过）。

## 数据位置

- 配置：`UserDefaults`（命令行直跑时域为 `Focus`，.app 运行时为 `com.yidong.focus`）
- 日志：`~/Library/Application Support/Focus/events.db`

## 已知限制与路线图

- 属于**软拦截**：强退进程（活动监视器/`kill`）可绕过。路线图：方案 B（启动即终止/挂起）与"生效期不可退出"。
- 遮罩期间可通过系统快捷键切换 Space，遮罩会跟随所有 Space 显示，但不锁键盘以外的操作。
- 浏览器只按"整个应用"拦截，网址级拦截（SelfControl 式 hosts）可后续叠加。
- 目前不区分"工作时段/休息时段"，可加定时规则。
