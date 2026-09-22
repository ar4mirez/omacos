#!/usr/bin/env bash
source "$HOME/.local/state/omacos/current/theme/sketchybar.sh" 2>/dev/null || true

percent=$(pmset -g batt | grep -Eo '\d+%' | cut -d% -f1)
charging=$(pmset -g batt | grep -c 'AC Power')
[[ -z $percent ]] && { sketchybar --set "$NAME" drawing=off; exit 0; }

if (( charging )); then icon=""; color="${GREEN:-0xff9ece6a}"
elif (( percent > 80 )); then icon=""; color="${LABEL_COLOR:-0xffffffff}"
elif (( percent > 50 )); then icon=""; color="${LABEL_COLOR:-0xffffffff}"
elif (( percent > 20 )); then icon=""; color="${YELLOW:-0xffe0af68}"
else icon=""; color="${RED:-0xfff7768e}"; fi

sketchybar --set "$NAME" icon="$icon" icon.color="$color" label="${percent}%"
