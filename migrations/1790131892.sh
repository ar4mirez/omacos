echo "Read QR codes off the screen, without ever showing what they said"

keymap="${XDG_CONFIG_HOME:-$HOME/.config}/omacos/keymap.conf"

if omacos-feature check desktop 2>/dev/null && command -v omacos-keymap-build >/dev/null; then
  omacos-keymap-build >/dev/null || echo "  keymap build failed — run: omacos keymap build"
  if [[ -f $keymap ]] && ! grep -q 'omacos-capture-qr' "$keymap"; then
    echo "  new: alt-ctrl-shift-o reads a QR code from a region of screen"
    echo "  take it with: omacos refresh config omacos/keymap.conf"
  fi
fi

# The helper gained the decoder, so a machine that built it before this needs
# it again. It only recompiles when the source is newer, so this is cheap.
if command -v omacos-cmd-build-helper >/dev/null; then
  omacos-cmd-build-helper >/dev/null 2>&1 || echo "  run: omacos cmd build-helper"
fi

echo "  the value goes to the clipboard and nowhere else — not printed, not in"
echo "  the notification, and marked concealed so the history skips it"
