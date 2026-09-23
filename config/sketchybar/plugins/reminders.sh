#!/usr/bin/env bash
# Shows while a countdown reminder is pending, with how many and how long until
# the next one fires. A reminder is a detached sleep that does not survive a
# reboot, so the bar is the only place it is visible at all.
source "$HOME/.local/state/omacos/current/theme/sketchybar.sh" 2>/dev/null || true

store="${XDG_STATE_HOME:-$HOME/.local/state}/omacos/reminders"

count=0
soonest=""
now=$(date +%s)

for file in "$store"/*; do
  [[ -f $file ]] || continue
  IFS=$'\t' read -r due pid _ < "$file" || continue
  # Same reaping rule as `omacos reminder list`: a reminder whose process is
  # gone has already fired or died with its session, so it is not pending.
  kill -0 "$pid" 2>/dev/null || { rm -f "$file"; continue; }
  count=$((count + 1))
  [[ -z $soonest || $due -lt $soonest ]] && soonest=$due
done

if (( count == 0 )); then
  sketchybar --set "$NAME" drawing=off
  exit 0
fi

# Minutes, rounded up, so a reminder 30 seconds out reads as 1 rather than 0.
minutes=$(( (soonest - now + 59) / 60 ))
(( minutes < 0 )) && minutes=0

if (( count == 1 )); then
  label="${minutes}m"
else
  label="${minutes}m ·${count}"
fi

sketchybar --set "$NAME" drawing=on icon="◔" icon.color="${YELLOW:-0xffe0af68}" label="$label"
