#!/bin/zsh
# FocusSeal uninstaller — removes the schedule, binary, and symlink.

FSDIR="$HOME/.focus-seal"
LABEL="com.focusseal"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
ISLAND_PLIST="$HOME/Library/LaunchAgents/com.focusisland.plist"

echo "==> FocusSeal uninstall"

launchctl unload "$PLIST" 2>/dev/null && echo "    schedule unloaded"
rm -f "$PLIST" && echo "    removed $PLIST"
launchctl unload "$ISLAND_PLIST" 2>/dev/null && echo "    notch island unloaded"
rm -f "$ISLAND_PLIST" && echo "    removed $ISLAND_PLIST"
pkill -f "$FSDIR/bin/focus-island" 2>/dev/null

# kill a seal that happens to be on screen right now
pkill -f "$FSDIR/bin/focus-seal" 2>/dev/null && echo "    stopped a running seal"

rm -f "$HOME/bin/focusseal" && echo "    removed ~/bin/focusseal"
rm -rf "$FSDIR" && echo "    removed $FSDIR"

echo ""
echo "==> Done. The PATH line in ~/.zshrc (if added) is left alone; remove it by hand if you want."
