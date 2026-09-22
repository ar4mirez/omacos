echo "Add capture, clipboard history, notices, reminders and toggles"

# Everything here is a no-op the second time: a rebuilt keymap is byte-identical,
# the helper is only compiled when its source is newer, and the watcher is only
# started when it is not already loaded.

keymap="${XDG_CONFIG_HOME:-$HOME/.config}/omacos/keymap.conf"

if omacos-feature check desktop 2>/dev/null && command -v omacos-keymap-build >/dev/null; then
  omacos-keymap-build >/dev/null
  # ~/.config is yours and is never rewritten, so a keymap seeded before this
  # release cannot contain the bindings it adds — rebuilding only regenerates
  # what is already in your file. Claiming the new keys work would be a lie you
  # only discover by pressing one.
  if [[ -f $keymap ]] && ! grep -q 'omacos-capture-screenshot' "$keymap"; then
    echo "  your keymap predates the capture, clipboard, notice and toggle bindings"
    echo "  take the new one with: omacos refresh config omacos/keymap.conf"
  else
    echo "  keymap rebuilt"
  fi
fi

if command -v omacos-cmd-build-helper >/dev/null; then
  if omacos-cmd-build-helper >/dev/null 2>&1; then
    echo "  native helper built (OCR, colour picker)"
  else
    echo "  native helper could not be built — run: omacos cmd build-helper"
  fi
fi

if command -v omacos-setup-clipboard >/dev/null; then
  if omacos-setup-clipboard status >/dev/null 2>&1; then
    :
  elif omacos-setup-clipboard on >/dev/null 2>&1; then
    echo "  clipboard history started — off again with: omacos setup clipboard off"
  else
    # A watcher that failed to start is a hotkey that does nothing later, so
    # the failure gets said out loud rather than swallowed by the branch.
    echo "  could not start the clipboard watcher — run: omacos setup clipboard"
  fi
fi

# Same boundary as the keymap: the status bar keeps whatever sketchybarrc it
# already has. Say what taking the new one would add rather than reaching into
# a file whose owner is someone else.
bar="${XDG_CONFIG_HOME:-$HOME/.config}/sketchybar/sketchybarrc"
if [[ -f $bar ]] && ! grep -q omacos_recording "$bar"; then
  echo "  your sketchybarrc predates the recording and idle indicators"
  echo "  take the new one with: omacos refresh config sketchybar/sketchybarrc"
fi
