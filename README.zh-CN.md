# FocusSeal — 整点强制休息封条

每小时 **:00** 和 **:30**，用一个巨大的纯黑 X 把 Mac 屏幕封住 5 分钟。

不是一个能点掉的提醒，是一张得等它自己揭开的封条。封条揭开时，你得先写下接下来这半小时要做什么，
才能拿回屏幕。这个目标会一直待在 MacBook 刘海下面的一个小胶囊里。

[English](README.md)

## 为什么这么做

真正有效的休息是**提前、高频、短时**的，而不是等你已经累垮了再补一个长假。
所以它不等你觉得累，也不问你同不同意。每小时两次，到点就把屏幕拿走 5 分钟。

## 长什么样

整屏遮黑到 93%，一个像封条一样粗的纯黑 X 横铺全屏，从角到角。
倒计时落在交叉点上，下面一行「停下来。看远处，站起来，喝水。」
接了几块显示器，每块屏都盖一个 X。

## 安装

需要 macOS 和 Xcode 命令行工具（`xcode-select --install`）。

```sh
git clone https://github.com/LemonPP-byte/focus-seal.git
cd focus-seal
./install.sh
```

安装脚本会编译二进制、装好 launchd 调度并启用它。重启也不用管，登录时自动恢复，
从此不需要手动启动任何东西。

不想等到整点，想立刻看看效果：

```sh
~/.focus-seal/focusseal test 8
```

## 休息结束：写下下一段目标才放行

倒计时走完**不会自动解封**。屏幕中间出现输入框「休息结束。下一段做什么？」，写下这一段要做的事
（至少 2 个字，支持中文输入法），回车才解封。空着回车，输入框会抖一下，不放行。

输入框里的灰色提示会显示上一段的目标。每条目标都会带时间戳记进 `~/.focus-seal/focus-seal.log`，
一天下来就是一份现成的 timebox 日志。

## 刘海目标胶囊

刚写下的目标会放进一个从 MacBook 刘海里长出来的黑色胶囊：左边是目标，右边是距下次休息的分钟数。
它**平时藏在刘海里看不见**，只在这几个时刻探出来几秒：

- 刚写完新目标时
- **:25 / :55**，休息前 5 分钟，提醒收尾
- 鼠标停在刘海附近时

它不接收点击，也不抢键盘焦点。没有刘海的 Mac 上，它从菜单栏正中探出来。

## 紧急解锁

- 倒计时阶段：**直接键入** `overridebreak`，不用找输入框，盲打即可。屏幕底部会出现一排 `•`，
  确认按键收到了。
- 写目标阶段：在输入框里键入 `overridebreak` 并回车（会记进日志）。

想让自己更难糊弄，把 `UNLOCK_PHRASE` 改长一点（见[调参](#调参)）。

## 命令

```sh
focusseal status        # 看调度状态、当前是否封屏中、下次什么时候
focusseal off           # 彻底停用调度
focusseal on            # 重新启用
focusseal pause 90      # 暂停 90 分钟后自动恢复（开会、演示用）
focusseal resume        # 提前结束暂停
focusseal test 8        # 试跑 8 秒
focusseal now 300       # 立刻封屏 300 秒
focusseal rebuild       # 改完源码后重新编译
focusseal goal "..."    # 手动设置胶囊里的目标（goal 查看、goal clear 清空）
focusseal island off    # 关掉刘海胶囊（island on 重新打开）
```

`focusseal` 已软链到 `~/bin`。如果 PATH 还没生效，开个新终端，或者直接用全路径
`~/.focus-seal/focusseal`。

临时中断优先用 `pause` 而不是 `off`——它会自己开回来，你没机会忘。

## 封屏期间被堵住的逃生路

| 逃生路 | 拦截方式 |
|---|---|
| Cmd-Q、Cmd-W、任何按键 | 所有键盘事件被吞掉 |
| Cmd-Tab 切换应用 | `disableProcessSwitching` |
| Cmd-Opt-Esc 强制退出 | `disableForceQuit` |
| Dock、菜单栏 | 隐藏 |
| 鼠标点击 | 被窗口吞掉，穿不到下层 |

**保底出口：** 程序内置 1500 秒（25 分钟）硬上限，无条件退出——万一解锁短语失灵也能出来。
这个时长足够长，干等过不了写目标这一关；又足够短，赶在下一次封屏之前结束。
这条很重要，因为其他路都被故意堵死了。另外可以从另一台设备 ssh 进来
`pkill -f bin/focus-seal`。

写目标阶段，窗口会从屏蔽级降到 floating 级，否则中文输入法的候选框会被封条盖住。
这时 Cmd 组合键仍被吞掉，应用切换仍被禁用。

它**没有**堵住的：物理电源键，以及 Ctrl-Cmd-Q 锁屏。这是给自己的习惯设一道减速带，
不是做一个真正锁死的展台机。

## 调参

改 `~/.focus-seal/src/FocusSeal.swift`，然后 `focusseal rebuild`：

| 常量 | 默认值 | 含义 |
|---|---|---|
| `UNLOCK_PHRASE` | `overridebreak` | 解锁短语，想更硬就改长 |
| `SCRIM_ALPHA` | `0.93` | X 以外区域的遮黑程度，`1.0` = 全黑 |
| `X_THICKNESS` | `0.13` | X 笔画粗细，占屏幕短边的比例 |
| `HARD_LIMIT` | `1500` | 保底强制退出秒数（含写目标阶段） |
| `MIN_GOAL_CHARS` | `2` | 目标最少字数 |

休息时长：改 `computeDuration()` 里的 `300`。
频率：改 `~/Library/LaunchAgents/com.focusseal.plist` 里的 `StartCalendarInterval`，
然后 `focusseal off && focusseal on`。多加几个
`<dict><key>Minute</key><integer>15</integer></dict>` 就变成每 15 分钟一次。

胶囊的停留秒数、悬停灵敏度、最大宽度在 `~/.focus-seal/src/FocusIsland.swift` 顶部常量里，
改完 `focusseal rebuild`。

## 已知行为

- **:00 / :30 时电脑在睡觉？** 唤醒后 launchd 会补触发。如果那 5 分钟窗口已经过了，
  只封 60 秒，不会突然占满 5 分钟。
- **多显示器：** 每块屏都盖一个 X，倒计时画在主屏。
- 封屏中途插拔显示器会自动重建窗口。
- 两张封条不会叠加——第二次触发发现前一个还在跑就跳过。

## 卸载

```sh
./uninstall.sh
```

会移除两个 launchd 服务、二进制、`~/.focus-seal` 和软链。`~/.zshrc` 里的 PATH 那行不动。

## 文件

```
~/.focus-seal/src/FocusSeal.swift              封条源码
~/.focus-seal/src/FocusIsland.swift            刘海胶囊源码
~/.focus-seal/bin/focus-seal                   封条编译产物
~/.focus-seal/bin/focus-island                 胶囊编译产物
~/.focus-seal/focusseal                        控制脚本
~/.focus-seal/goal.txt                         当前目标
~/.focus-seal/focus-seal.log                   运行日志 + 目标日志
~/Library/LaunchAgents/com.focusseal.plist     调度
~/Library/LaunchAgents/com.focusisland.plist   胶囊（登录启动，挂了自动拉起）
```

## 许可

MIT
