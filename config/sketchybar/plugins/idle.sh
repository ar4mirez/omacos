#!/usr/bin/env bash
# Shows only while idle sleep is being held off (`omacos toggle idle`), which
# is the kind of state that is easy to leave on for a week.
source "$HOME/.local/state/omacos/current/theme/sketchybar.sh" 2>/dev/null || true

pidfile="${XDG_STATE_HOME:-$HOME/.local/state}/omacos/caffeinate.pid"
pid=$(cat "$pidfile" 2>/dev/null) || pid=""

if [[ -n $pid ]] && kill -0 "$pid" 2>/dev/null; then
  sketchybar --set "$NAME" drawing=on icon="☕" icon.color="${YELLOW:-0xffe0af68}" label.drawing=off
else
  sketchybar --set "$NAME" drawing=off
fi
