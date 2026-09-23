#!/usr/bin/env bash
# Shows when an omacos update is waiting. Omarchy puts a circle arrow beside
# the clock for this; clicking it starts the update.
#
# The network call lives in `omacos cmd update-check`, which caches its answer,
# so this redraws for free and asks the remote at most twice an hour.
source "$HOME/.local/state/omacos/current/theme/sketchybar.sh" 2>/dev/null || true

if omacos-cmd-update-check 2>/dev/null; then
  sketchybar --set "$NAME" drawing=on icon="↻" icon.color="${GREEN:-0xff9ece6a}" label.drawing=off
else
  sketchybar --set "$NAME" drawing=off
fi
