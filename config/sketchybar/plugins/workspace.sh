#!/usr/bin/env bash
# Highlights the focused workspace. $FOCUSED_WORKSPACE comes from AeroSpace's
# exec-on-workspace-change; $NAME is this item ("space.<n>").
source "$HOME/.local/state/omacos/current/theme/sketchybar.sh" 2>/dev/null || true

if [[ ${FOCUSED_WORKSPACE:-} == "${NAME#space.}" ]]; then
  sketchybar --set "$NAME" background.drawing=on \
                           label.color="${HIGHLIGHT_COLOR:-0xffffffff}"
else
  sketchybar --set "$NAME" background.drawing=off \
                           label.color="${DIM_COLOR:-0xff888888}"
fi
