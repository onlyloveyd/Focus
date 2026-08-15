Focus v0.1.0 —— 首个发布版本

一台"意识闸机"：名单内的应用进入前台时，全屏遮罩会要求你度过冷静期、写下具体原因，然后才能继续。不消灭行为，只要求行为携带意识。

## 功能

- 前台应用监控 + 全屏遮罩，冷静期倒计时 + 原因最少字数校验
- 三套弹窗文案：标准 / 凶狠 / 温柔治愈，菜单栏即时切换
- 拦截名单管理（从运行中的应用点选添加），摩擦参数可调
- SQLite 本地记录每次"打开了 / 忍住了"，7 天汇总 + 明细回顾
- 说明原因后限时免拦（默认 5 分钟），处处留门，可暂停 30 分钟
- universal 双架构（Apple Silicon & Intel），macOS 13+，无需任何特殊权限

## 安装

1. 下载 `Focus.dmg`，把 Focus 拖入 Applications；
2. 首次打开（⚠️ 未签名未公证）：系统设置 → 隐私与安全性 → 点「仍要打开」，或终端执行 `xattr -d com.apple.quarantine /Applications/Focus.app`；
3. 建议在 系统设置 → 通用 → 登录项 里添加开机启动。

设计哲学见仓库 [DESIGN.md](https://github.com/onlyloveyd/Focus/blob/main/DESIGN.md)。
