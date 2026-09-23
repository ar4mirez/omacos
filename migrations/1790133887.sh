echo "The last of the small things: a badge, Low Power Mode, a prompt, a debug report"

bar="${XDG_CONFIG_HOME:-$HOME/.config}/sketchybar/sketchybarrc"
click="${XDG_CONFIG_HOME:-$HOME/.config}/sketchybar/plugins/click.sh"

if [[ -f $bar ]] && ! grep -q 'add item update' "$bar"; then
  echo "  your bar has no update badge yet"
  echo "    omacos refresh config sketchybar/sketchybarrc"
  echo "    omacos refresh config sketchybar/plugins/click.sh"
  echo "    sketchybar --reload"
elif [[ -f $click ]] && ! grep -q 'update\.\*' "$click"; then
  echo "  your click table has no row for the update badge"
  echo "    omacos refresh config sketchybar/plugins/click.sh"
fi

# starship.toml is seeded automatically if absent. Anyone who already has one
# keeps it, and should know a default now exists to compare against.
prompt="${XDG_CONFIG_HOME:-$HOME/.config}/starship.toml"
if [[ -f $prompt ]] && ! grep -q 'omacos seeded it once' "$prompt"; then
  echo "  you already have a starship.toml, so yours was kept"
  echo "  omacos now ships one: omacos refresh config starship.toml"
fi

echo "  omacos toggle lowpower   — the nearest thing macOS has to power profiles"
echo "  omacos debug             — a report for an issue, with no values from local.env"
echo "  tldr, yt-dlp and try are now installed with everything else"
