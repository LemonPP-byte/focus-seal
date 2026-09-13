# FocusSeal

Seals your Mac's screen with a giant black X for 5 minutes at **:00** and **:30** of every hour.

Not a reminder you can dismiss. A seal you have to wait out.

[中文说明](README.zh-CN.md)

## Why

The rest that actually works is **early, frequent, and short** — not a long break bolted on after
you're already fried. So this doesn't wait for you to feel tired, and it doesn't ask permission.
Twice an hour, on the clock, the screen goes away for five minutes.

## What it looks like

The whole screen dims to 93% black. A pure-black X, thick as a shipping seal, spans corner to
corner. The countdown sits at the crossing point, with one line under it: *stop, look far away,
stand up, drink water.* Every attached display gets its own X.

## Install

Requires macOS and Xcode Command Line Tools (`xcode-select --install`).

```sh
git clone https://github.com/LemonPP-byte/focus-seal.git
cd focus-seal
./install.sh
```

That compiles the binary, installs a launchd agent, and enables the schedule. It survives reboots —
launchd starts it at login. Nothing to launch by hand, ever.

See it immediately without waiting for the clock:

```sh
~/.focus-seal/focusseal test 8
```

## Unlock

While the screen is sealed, **just type** `overridebreak`. No text field to find, no prompt — type
it blind. A row of `•` at the bottom confirms your keystrokes are landing.

Make it harder on yourself by setting `UNLOCK_PHRASE` to something longer (see [Tuning](#tuning)).

## Commands

```sh
focusseal status        # schedule state, whether a seal is up, next trigger
focusseal off           # stop the schedule entirely
focusseal on            # re-enable it
focusseal pause 90      # suspend for 90 min, then auto-resume (meetings, demos)
focusseal resume        # end a pause early
focusseal test 8        # 8-second dry run
focusseal now 300       # seal right now for 300 seconds
focusseal rebuild       # recompile after editing the source
```

`focusseal` is symlinked into `~/bin`. If that's not on your PATH yet, open a new terminal, or call
`~/.focus-seal/focusseal` directly.

For a temporary interruption prefer `pause` over `off` — it turns itself back on, so you can't
forget to.

## What's blocked during a seal

| Escape route | Handled by |
|---|---|
| Cmd-Q, Cmd-W, any keystroke | all key events swallowed |
| Cmd-Tab | `disableProcessSwitching` |
| Cmd-Opt-Esc (Force Quit) | `disableForceQuit` |
| Dock, menu bar | hidden |
| Mouse clicks | absorbed, never reach what's underneath |

**Backstop:** a 420-second hard ceiling inside the program exits unconditionally, even if the
unlock phrase somehow fails. This matters because everything else is deliberately blocked — from
another machine, `ssh` in and `pkill -f bin/focus-seal`.

What it does *not* block: the physical power button, and Ctrl-Cmd-Q to lock the screen. It's a
speed bump against your own habits, not a kiosk lockdown.

## Tuning

Edit `~/.focus-seal/src/FocusSeal.swift`, then `focusseal rebuild`:

| Constant | Default | Meaning |
|---|---|---|
| `UNLOCK_PHRASE` | `overridebreak` | unlock phrase — make it longer to make it harder |
| `SCRIM_ALPHA` | `0.93` | darkness outside the X; `1.0` is fully opaque |
| `X_THICKNESS` | `0.13` | stroke width, as a fraction of the screen's short edge |
| `HARD_LIMIT` | `420` | backstop force-exit, in seconds |

Break length: change `300` in `computeDuration()`.
Frequency: edit `StartCalendarInterval` in `~/Library/LaunchAgents/com.focusseal.plist`, then
`focusseal off && focusseal on`. Adding `<dict><key>Minute</key><integer>15</integer></dict>`
entries gets you every 15 minutes.

## Behavior worth knowing

- **Asleep at :00 or :30?** launchd fires late on wake. If the 5-minute window has already passed,
  you get a 60-second seal instead of a full one suddenly eating your time.
- **Multiple displays:** each screen gets an X; the countdown draws on the main one.
- Plugging or unplugging a display mid-seal rebuilds the windows.
- Two seals can't stack — a second trigger sees the first still running and skips.

## Uninstall

```sh
./uninstall.sh
```

Removes the schedule, the binary, `~/.focus-seal`, and the symlink. The PATH line in `~/.zshrc` is
left alone.

## Files

```
~/.focus-seal/src/FocusSeal.swift              source
~/.focus-seal/bin/focus-seal                   compiled binary
~/.focus-seal/focusseal                        control script
~/.focus-seal/focus-seal.log                   run log
~/Library/LaunchAgents/com.focusseal.plist     schedule
```

## License

MIT
