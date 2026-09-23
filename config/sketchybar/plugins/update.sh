#!/usr/bin/env bash
# Shows when an omacos update is waiting. Omarchy puts a circle arrow beside
# the clock for this; clicking it starts the update.
#
# The network call lives in `omacos cmd update-check`, which caches its answer,
# so this redraws for free and asks the remote at most twice an hour.
source "$HOME/.local/state/omacos/current/theme/sketchybar.sh" 2>/dev/null || true

# sketchybar does not necessarily inherit a login shell's PATH — how it was
# started decides, and a launchd-started bar has none of it. Without this, every
# omacos command below is "command not found", which for a click is silence and
# for the update check is indistinguishable from "no update".
# shellcheck source=/dev/null
. "${OMACOS_PATH:-$HOME/.local/share/omacos}/default/env-bootstrap" 2>/dev/null || true


if omacos-cmd-update-check 2>/dev/null; then
  sketchybar --set "$NAME" drawing=on icon="↻" icon.color="${GREEN:-0xff9ece6a}" label.drawing=off
else
  sketchybar --set "$NAME" drawing=off
fi
