step_heading "Packages"

say "Installing the core Brewfile (this is the slow one)…"
brew bundle install --file "$OMACOS_PATH/Brewfile" --no-upgrade
ok "Core packages"

if omacos-feature check desktop 2>/dev/null; then
  say "Installing the desktop Brewfile…"
  brew bundle install --file "$OMACOS_PATH/Brewfile.desktop" --no-upgrade
  ok "Desktop packages"
else
  skip "Desktop layer off — enable with: omacos feature enable desktop"
fi
