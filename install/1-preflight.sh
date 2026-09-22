step_heading "Preflight"

if [[ $(uname -s) != Darwin ]]; then
  printf '\033[31momacos is macOS only.\033[0m\n' >&2; exit 1
fi
if [[ $(uname -m) != arm64 ]]; then
  printf '\033[31momacos targets Apple silicon.\033[0m\n' >&2; exit 1
fi

macos_version=$(sw_vers -productVersion)
case ${macos_version%%.*} in
  26) ok "macOS $macos_version" ;;
  27) warn "macOS $macos_version is very new — the window manager and status bar have limited testing here" ;;
  *)  warn "macOS $macos_version is outside the tested range (26–27)" ;;
esac

if ! xcode-select -p >/dev/null 2>&1; then
  say "Installing Xcode Command Line Tools (a dialog will open)…"
  xcode-select --install || true
  until xcode-select -p >/dev/null 2>&1; do sleep 5; done
fi
ok "Xcode Command Line Tools"

if ! have brew; then
  say "Installing Homebrew…"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi
ok "Homebrew $(brew --version | head -1 | awk '{print $2}')"
