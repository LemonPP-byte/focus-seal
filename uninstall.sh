#!/bin/zsh
# FocusSeal uninstaller — removes the schedule, binary, and symlink.

FSDIR="$HOME/.focus-seal"
LABEL="com.focusseal"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

echo "==> FocusSeal uninstall"

launchctl unload "$PLIST" 2>/dev/null && echo "    schedule unloaded"
rm -f "$PLIST" && echo "    removed $PLIST"

# kill a seal that happens to be on screen right now
pkill -f "$FSDIR/bin/focus-seal" 2>/dev/null && echo "    stopped a running seal"

rm -f "$HOME/bin/focusseal" && echo "    removed ~/bin/focusseal"
rm -rf "$FSDIR" && echo "    removed $FSDIR"

echo ""
echo "==> Done. The PATH line in ~/.zshrc (if added) is left alone; remove it by hand if you want."
