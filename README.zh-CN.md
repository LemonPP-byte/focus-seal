# FocusSeal — 整点强制休息封条

每小时 **:00** 和 **:30**，用一个巨大的纯黑 X 把 Mac 屏幕封住 5 分钟。

不是一个能点掉的提醒，是一张得等它自己揭开的封条。

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

## 解锁

封屏时**直接键入** `overridebreak`。不用找输入框，也没有提示框，盲打即可。
屏幕底部会出现一排 `•`，确认按键收到了。

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

**保底出口：** 程序内置 420 秒硬上限，无条件退出——万一解锁短语失灵也能出来。
这条很重要，因为其他路都被故意堵死了。另外可以从另一台设备 ssh 进来
`pkill -f bin/focus-seal`。

它**没有**堵住的：物理电源键，以及 Ctrl-Cmd-Q 锁屏。这是给自己的习惯设一道减速带，
不是做一个真正锁死的展台机。

## 调参

改 `~/.focus-seal/src/FocusSeal.swift`，然后 `focusseal rebuild`：

| 常量 | 默认值 | 含义 |
|---|---|---|
| `UNLOCK_PHRASE` | `overridebreak` | 解锁短语，想更硬就改长 |
| `SCRIM_ALPHA` | `0.93` | X 以外区域的遮黑程度，`1.0` = 全黑 |
| `X_THICKNESS` | `0.13` | X 笔画粗细，占屏幕短边的比例 |
| `HARD_LIMIT` | `420` | 保底强制退出秒数 |

休息时长：改 `computeDuration()` 里的 `300`。
频率：改 `~/Library/LaunchAgents/com.focusseal.plist` 里的 `StartCalendarInterval`，
然后 `focusseal off && focusseal on`。多加几个
`<dict><key>Minute</key><integer>15</integer></dict>` 就变成每 15 分钟一次。

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

会移除调度、二进制、`~/.focus-seal` 和软链。`~/.zshrc` 里的 PATH 那行不动。

## 文件

```
~/.focus-seal/src/FocusSeal.swift              源码
~/.focus-seal/bin/focus-seal                   编译产物
~/.focus-seal/focusseal                        控制脚本
~/.focus-seal/focus-seal.log                   运行日志
~/Library/LaunchAgents/com.focusseal.plist     调度
```

## 许可

MIT
