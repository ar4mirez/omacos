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
