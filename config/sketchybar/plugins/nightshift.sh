#!/usr/bin/env bash
# Shows while Night Shift is warming the screen.
#
# This one draws only when it can actually tell. macOS keeps Night Shift behind
# CoreBrightness, a private framework with no readable preference, so the only
# honest source is the `nightlight` CLI — which omacos will use if you have it
# but will not install for you (see `omacos toggle nightlight`).
#
# Without it the indicator stays dark rather than guessing from the last time
# omacos toggled something: an indicator that is right most of the time is the
# one you stop believing.
source "$HOME/.local/state/omacos/current/theme/sketchybar.sh" 2>/dev/null || true

if ! command -v nightlight >/dev/null 2>&1; then
  sketchybar --set "$NAME" drawing=off
  exit 0
fi

status=$(nightlight status 2>/dev/null) || status=""

if [[ $status == *on* ]]; then
  sketchybar --set "$NAME" drawing=on icon="☾" icon.color="${YELLOW:-0xffe0af68}" label.drawing=off
else
  sketchybar --set "$NAME" drawing=off
fi
