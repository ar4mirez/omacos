step_heading "Packages"

say "Installing the core Brewfile (this is the slow one)…"
brew bundle install --file "$OMACOS_PATH/Brewfile" --no-upgrade
ok "Core packages"

if omacos-feature check desktop 2>/dev/null; then
  # Homebrew 7 refuses formulae from untrusted taps, so this has to happen
  # before brew bundle rather than being left for the user to discover.
  omacos-cmd-trust-tap nikitabobko/tap "AeroSpace" || true
  omacos-cmd-trust-tap felixkratz/formulae "SketchyBar and JankyBorders" || true

  say "Installing the desktop Brewfile…"
  brew bundle install --file "$OMACOS_PATH/Brewfile.desktop" --no-upgrade
  ok "Desktop packages"
else
  skip "Desktop layer off — enable with: omacos feature enable desktop"
fi

if omacos-feature check apps 2>/dev/null; then
  say "Installing GUI applications…"
  # Routed through omacos-install-app rather than brew bundle: some of these
  # are .pkg casks that need one sudo prompt, which bundle cannot manage.
  mapfile -t app_casks < <(grep '^cask ' "$OMACOS_PATH/Brewfile.apps" | cut -d'"' -f2)
  ((${#app_casks[@]})) && omacos-install-app "${app_casks[@]}"
  ok "Applications"
else
  skip "App layer off — enable with: omacos feature enable apps"
fi
