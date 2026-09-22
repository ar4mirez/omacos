#!/usr/bin/env bash
# Shows only while `omacos capture screenrecording` has something running, so
# a recording you forgot about is visible rather than silent.
source "$HOME/.local/state/omacos/current/theme/sketchybar.sh" 2>/dev/null || true

pidfile="${XDG_STATE_HOME:-$HOME/.local/state}/omacos/screenrecording.pid"
pid=$(cat "$pidfile" 2>/dev/null) || pid=""

if [[ -n $pid ]] && kill -0 "$pid" 2>/dev/null; then
  sketchybar --set "$NAME" drawing=on icon="●" icon.color="${RED:-0xfff7768e}" label="REC"
else
  sketchybar --set "$NAME" drawing=off
fi
