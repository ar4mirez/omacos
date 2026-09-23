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

# Omarchy fires a battery-low hook, and this is the only thing on the machine
# that looks at the battery often enough to notice. Edge-triggered: the level
# it last fired at is remembered, so a hook runs when you cross the threshold
# and not every two minutes until you find a charger.
state="${XDG_STATE_HOME:-$HOME/.local/state}/omacos"
marker="$state/battery-low-fired"
threshold=${OMACOS_BATTERY_LOW:-20}

if (( charging )) || (( percent > threshold )); then
  rm -f "$marker"
elif [[ ! -f $marker ]]; then
  mkdir -p "$state"
  printf '%s\n' "$percent" > "$marker"
  # shellcheck source=/dev/null
  . "${OMACOS_PATH:-$HOME/.local/share/omacos}/default/env-bootstrap" 2>/dev/null || true
  omacos-hook battery-low "$percent" >/dev/null 2>&1 || true
fi
