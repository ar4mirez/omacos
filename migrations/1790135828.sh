echo "Tell the truth about the menu bar, and let you set the font size"

# The helper gained a menubar check; rebuild so `omacos toggle menubar` can
# measure rather than guess. Only recompiles when the source is newer.
if command -v omacos-cmd-build-helper >/dev/null; then
  omacos-cmd-build-helper >/dev/null 2>&1 || echo "  run: omacos cmd build-helper"
fi

# Saying this once is worth more than a correction later: the setting has
# always been written correctly and has never applied without a logout.
if [[ $(defaults read NSGlobalDomain _HIHideMenuBar 2>/dev/null || echo 0) == 1 ]]; then
  helper="${XDG_STATE_HOME:-$HOME/.local/state}/omacos/bin/omacos-helper"
  if [[ -x $helper ]] && [[ $("$helper" menubar 2>/dev/null) == visible* ]]; then
    echo "  you have asked for the menu bar to hide and it is still on screen —"
    echo "  macOS applies that at login. Log out and back in, or instead:"
    echo "    omacos bar position bottom"
  fi
fi

echo "  new: omacos font size 13 — the terminal ships at 14, which is large on"
echo "       an external display"
