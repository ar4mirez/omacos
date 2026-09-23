echo "Shrink a picture or a video before you send it"

keymap="${XDG_CONFIG_HOME:-$HOME/.config}/omacos/keymap.conf"

if omacos-feature check desktop 2>/dev/null && command -v omacos-keymap-build >/dev/null; then
  omacos-keymap-build >/dev/null || echo "  keymap build failed — run: omacos keymap build"
  if [[ -f $keymap ]] && ! grep -q 'omacos-transcode' "$keymap"; then
    echo "  new: alt-ctrl-period shrinks a picture or video"
    echo "  take it with: omacos refresh config omacos/keymap.conf"
  fi
fi

# The helper gained copy-file, so a tree that built it before this needs it
# again. It only recompiles when the source is newer.
if command -v omacos-cmd-build-helper >/dev/null; then
  omacos-cmd-build-helper >/dev/null 2>&1 || echo "  run: omacos cmd build-helper"
fi

echo "  omacos transcode — sips and avconvert, both already on this Mac"
echo "  the result goes on the clipboard as a file, so pasting into Mail attaches it"
