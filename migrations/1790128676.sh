echo "Show a pending reminder on the bar, and Night Shift where it can be read"

# The two new plugins are seeded automatically, because they are files that did
# not exist. The two that did — sketchybarrc and click.sh — are yours, and this
# never rewrites them; it only says what taking the new ones adds.

bar="${XDG_CONFIG_HOME:-$HOME/.config}/sketchybar/sketchybarrc"
click="${XDG_CONFIG_HOME:-$HOME/.config}/sketchybar/plugins/click.sh"

if [[ -f $bar ]] && ! grep -q 'add item reminders' "$bar"; then
  echo "  your bar predates the reminder and Night Shift indicators"
  echo "  take them with:"
  echo "    omacos refresh config sketchybar/sketchybarrc"
  echo "    omacos refresh config sketchybar/plugins/click.sh"
  echo "    sketchybar --reload"
elif [[ -f $click ]] && ! grep -q 'reminders.left' "$click"; then
  # The bar can have the items while the click table has no rows for them,
  # if only one of the two was refreshed.
  echo "  your click table has no rows for the new indicators"
  echo "  take it with: omacos refresh config sketchybar/plugins/click.sh"
fi
