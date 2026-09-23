echo "Reach one window directly, the way Omarchy's Super+Alt+1/2/3/4 does"

keymap="${XDG_CONFIG_HOME:-$HOME/.config}/omacos/keymap.conf"

if omacos-feature check desktop 2>/dev/null && command -v omacos-keymap-build >/dev/null; then
  omacos-keymap-build >/dev/null || echo "  keymap build failed — run: omacos keymap build"

  # The keymap is yours and is never rewritten, so say what taking the new one
  # adds rather than claiming keys that are not actually reachable.
  if [[ -f $keymap ]] && ! grep -q 'dfs-index' "$keymap"; then
    echo "  new: alt-ctrl-1..4 focuses the 1st..4th window on this workspace,"
    echo "       which inside a stack is the 1st..4th of the stack"
    echo "  take it with: omacos refresh config omacos/keymap.conf"
  fi
fi

echo "  new: omacos system info — what this machine is, in one panel"
