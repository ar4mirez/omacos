echo "Answer Omarchy's navigation chapter: arrows, pinning, a scratchpad that toggles"

# Two halves, as usual. The AeroSpace base config is omacos's, so it is applied
# here; the keymap is yours, so this only says what taking the new one gets you.

keymap="${XDG_CONFIG_HOME:-$HOME/.config}/omacos/keymap.conf"

if omacos-feature check desktop 2>/dev/null && command -v omacos-keymap-build >/dev/null; then
  # Rebuild regardless of whether the keymap changed: base.toml did. It now
  # moves the pointer to the window you focus, carries pinned windows across a
  # workspace change, and drops stale pins when AeroSpace starts.
  omacos-keymap-build >/dev/null || echo "  keymap build failed — run: omacos keymap build"
  echo "  the pointer now follows the window you focus, as Omarchy's Super+Arrow does"

  if [[ -f $keymap ]] && ! grep -q 'omacos-window-pin' "$keymap"; then
    echo "  your keymap predates the navigation bindings:"
    echo "    alt-o            pin a window so it follows you to every workspace"
    echo "    alt-arrows       focus and move, alongside hjkl"
    echo "    alt-shift-cmd-N  send a window to workspace N and stay where you are"
    echo "    alt-cmd-w        close every window on this workspace"
    echo "    alt-ctrl-f       fullscreen, edge to edge"
    echo "    alt-shift-enter  the browser — the apps menu moves to alt-cmd-space"
    echo "    alt-s            now toggles the scratchpad instead of only entering it"
    echo "  take them with: omacos refresh config omacos/keymap.conf"
  fi
fi

# Pins are window ids and window ids belong to a single AeroSpace run, so an
# update is as good a moment as a restart to start from an empty set.
if command -v omacos-window-pin >/dev/null; then
  omacos-window-pin clear >/dev/null 2>&1 || true
fi

echo "  new: omacos window pin — and a Windows section in the omacos menu"
