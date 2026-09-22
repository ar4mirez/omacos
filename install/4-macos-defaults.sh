step_heading "macOS defaults"

# Keyboard — the single biggest quality-of-life win, and it matters most for a
# Neovim-first setup where held-key repeat is constant.
set_default NSGlobalDomain KeyRepeat int 2
set_default NSGlobalDomain InitialKeyRepeat int 15
set_default NSGlobalDomain ApplePressAndHoldEnabled bool 0
set_default NSGlobalDomain AppleKeyboardUIMode int 3

# Finder
set_default com.apple.finder AppleShowAllFiles bool 1
set_default NSGlobalDomain AppleShowAllExtensions bool 1
set_default com.apple.finder ShowPathbar bool 1
set_default com.apple.finder ShowStatusBar bool 1
set_default com.apple.finder FXPreferredViewStyle string Nlsv
set_default com.apple.finder _FXSortFoldersFirst bool 1
set_default com.apple.desktopservices DSDontWriteNetworkStores bool 1

# Screenshots
mkdir -p "$HOME/Screenshots"
set_default com.apple.screencapture location string "$HOME/Screenshots"
set_default com.apple.screencapture type string png
set_default com.apple.screencapture disable-shadow bool 1

# Dock
set_default com.apple.dock autohide bool 1
set_default com.apple.dock autohide-delay float 0
set_default com.apple.dock autohide-time-modifier float 0.15
set_default com.apple.dock show-recents bool 0

if omacos-feature check desktop 2>/dev/null; then
  # AeroSpace prerequisites. It does not use native Spaces — it parks inactive
  # windows off-screen in a monitor's bottom corner — so without these you get
  # windows leaking onto adjacent displays and Mission Control showing ghosts.
  set_default com.apple.spaces spans-displays bool 1
  set_default com.apple.dock expose-group-apps bool 1
  set_default com.apple.dock mru-spaces bool 0
  set_default NSGlobalDomain NSAutomaticWindowAnimationsEnabled bool 0
  set_default NSGlobalDomain NSWindowResizeTime float 0.001
fi

killall Dock Finder SystemUIServer 2>/dev/null || true
ok "Restarted Dock, Finder and SystemUIServer"

# Caps Lock is the best-placed key on the board and does nothing useful. Remap
# it when local.env says to; hidutil needs no driver, so this is safe to script.
# shellcheck source=/dev/null
[[ -f $OMACOS_CONFIG/local.env ]] && . "$OMACOS_CONFIG/local.env"
if [[ -n ${CAPSLOCK:-} ]]; then
  omacos-setup-capslock "$CAPSLOCK" | sed 's/^/      /'
else
  skip "Caps Lock unchanged — set CAPSLOCK=option in local.env to remap it"
fi
