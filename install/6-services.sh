step_heading "Services"

if ! omacos-feature check desktop 2>/dev/null; then
  skip "Desktop layer off — enable with: omacos feature enable desktop"
else
  omacos-keymap-build

  for service in aerospace borders sketchybar; do
    if command -v "$service" >/dev/null || [[ -d /Applications/AeroSpace.app ]]; then
      ok "$service installed"
    else
      warn "$service missing — run: omacos install feature desktop"
    fi
  done

  # Accessibility cannot be granted from a script, so ask rather than pretend.
  if [[ -d /Applications/AeroSpace.app ]] && ! aerospace list-workspaces --all >/dev/null 2>&1; then
    warn "AeroSpace is not responding"
    say  "Grant Accessibility in System Settings > Privacy & Security, then relaunch it:"
    say  "  killall AeroSpace; open -a AeroSpace"
  fi
fi
