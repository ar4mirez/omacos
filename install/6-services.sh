step_heading "Services"

# The native helper backs OCR and the colour picker. Building it here means a
# failure is something you can read now, rather than a hotkey that does nothing
# in a week's time.
if omacos-cmd-build-helper >/dev/null 2>&1; then
  ok "Native helper built (OCR, colour picker)"
else
  warn "Could not build the native helper — run: omacos cmd build-helper"
fi

# Clipboard history is on by default, as it is in Omarchy. It records text you
# copy into ~/.local/state/omacos/clipboard, skips anything a password manager
# marks concealed, and keeps the last 200 entries.
if omacos-setup-clipboard status >/dev/null 2>&1; then
  ok "Clipboard history running"
elif omacos-setup-clipboard on >/dev/null 2>&1; then
  ok "Clipboard history started"
  say "Off again with: omacos setup clipboard off"
else
  warn "Could not start the clipboard watcher — run: omacos setup clipboard"
fi

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
