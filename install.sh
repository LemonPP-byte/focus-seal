#!/bin/zsh
# FocusSeal installer — builds the binary, installs the launchd agent, enables the schedule.
set -e

FSDIR="$HOME/.focus-seal"
LABEL="com.focusseal"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
REPO="${0:A:h}"

echo "==> FocusSeal install"

# --- preflight ---
if [[ "$(uname)" != "Darwin" ]]; then
  echo "Error: macOS only (uses Cocoa / launchd)." >&2
  exit 1
fi
if ! command -v swiftc > /dev/null 2>&1; then
  echo "Error: swiftc not found. Install Xcode Command Line Tools:" >&2
  echo "  xcode-select --install" >&2
  exit 1
fi

# --- refuse to trample a different FocusSeal-like agent already using $FSDIR ---
# (An earlier hand-rolled install may sit in the same directory under another label.
#  Installing over it would leave two agents both sealing the screen at :00.)
OTHER=$(launchctl list 2>/dev/null | awk '{print $3}' \
        | grep -i 'focusseal' | grep -v "^$LABEL$" || true)
if [[ -n "$OTHER" ]]; then
  echo "" >&2
  echo "Error: another FocusSeal-like launchd agent is already loaded:" >&2
  echo "$OTHER" | sed 's/^/  /' >&2
  echo "" >&2
  echo "It likely shares $FSDIR, so installing now would give you two agents" >&2
  echo "sealing the screen at once. Remove the old one first, e.g.:" >&2
  echo "$OTHER" | sed "s|^|  launchctl unload ~/Library/LaunchAgents/|;s|\$|.plist|" >&2
  echo "  rm ~/Library/LaunchAgents/<that-label>.plist" >&2
  echo "" >&2
  echo "Then re-run ./install.sh" >&2
  exit 1
fi

# --- lay out files ---
mkdir -p "$FSDIR/bin" "$FSDIR/src"
cp "$REPO/src/FocusSeal.swift" "$FSDIR/src/"
cp "$REPO/focusseal" "$FSDIR/focusseal"
chmod +x "$FSDIR/focusseal"

# --- build ---
echo "==> Compiling (may take ~10s)"
swiftc -O -o "$FSDIR/bin/focus-seal" "$FSDIR/src/FocusSeal.swift" -framework Cocoa
echo "    built: $FSDIR/bin/focus-seal"

# --- launchd agent, with the real home path substituted in ---
mkdir -p "$HOME/Library/LaunchAgents"
sed "s|__FSDIR__|$FSDIR|g" "$REPO/com.focusseal.plist.template" > "$PLIST"
plutil -lint "$PLIST" > /dev/null

# --- convenience command on PATH ---
mkdir -p "$HOME/bin"
ln -sf "$FSDIR/focusseal" "$HOME/bin/focusseal"

RC="$HOME/.zshrc"
if [[ -f "$RC" ]] && ! grep -q 'HOME/bin' "$RC"; then
  echo '' >> "$RC"
  echo '# added by FocusSeal' >> "$RC"
  echo 'export PATH="$HOME/bin:$PATH"' >> "$RC"
  echo "    added ~/bin to PATH in ~/.zshrc"
fi

# --- enable ---
launchctl unload "$PLIST" 2>/dev/null || true
launchctl load "$PLIST"

echo ""
echo "==> Done. FocusSeal is live."
echo "    Seals the screen for 5 minutes at :00 and :30 of every hour."
echo "    Unlock during a seal by typing: overridebreak"
echo ""
echo "    Try it now:  $FSDIR/focusseal test 8"
echo "    Status:      focusseal status   (new terminal, or use the full path above)"
echo "    Disable:     focusseal off"
