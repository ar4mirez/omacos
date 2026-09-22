step_heading "macOS defaults"

# Your file, read before anything is written: two of the defaults below are
# opinions you are allowed to disagree with (CAPSLOCK, DESKTOP_ICONS).
# shellcheck source=/dev/null
[[ -f $OMACOS_CONFIG/local.env ]] && . "$OMACOS_CONFIG/local.env"

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

  # "There is no dock and no desktop icons." The Dock already auto-hides
  # above; this is the other half. Nothing is deleted — ~/Desktop is still a
  # folder, and Finder still opens it — it just stops being a surface that
  # sits behind every window collecting files.
  #
  # Plenty of people work off the desktop, though, and an install that keeps
  # hiding icons you have put back is a fork waiting to happen. DESKTOP_ICONS
  # in local.env settles it either way.
  case ${DESKTOP_ICONS:-} in
    true|yes|1) skip "Desktop icons kept — DESKTOP_ICONS is set in local.env" ;;
    *)          set_default com.apple.finder CreateDesktop bool 0 ;;
  esac

  # And stop the wallpaper from being a button. Clicking empty space to reveal
  # the desktop shoves every tiled window off-screen, which with a tiling WM
  # is a way to lose your layout by missing a window edge.
  set_default com.apple.WindowManager EnableStandardClickToShowDesktop bool 0
fi

# WindowManager holds the click-to-show-desktop setting above and does not
# reread it on its own.
killall Dock Finder SystemUIServer WindowManager 2>/dev/null || true
ok "Restarted Dock, Finder, SystemUIServer and WindowManager"

# Caps Lock is the best-placed key on the board and does nothing useful. Remap
# it when local.env says to; hidutil needs no driver, so this is safe to script.
# local.env is already sourced at the top of this file.
if [[ -n ${CAPSLOCK:-} ]]; then
  omacos-setup-capslock "$CAPSLOCK" | sed 's/^/      /'
else
  skip "Caps Lock unchanged — set CAPSLOCK=option in local.env to remap it"
fi
