echo "Choose a font, and install more — Omarchy's Style > Font"

# omacos owns the generated font files and the catalog; it does not own the two
# configs that have to load them. Those are yours, so this names them and stops.

ghostty="${XDG_CONFIG_HOME:-$HOME/.config}/ghostty/config.ghostty"
bar="${XDG_CONFIG_HOME:-$HOME/.config}/sketchybar/sketchybarrc"
pending=false

if [[ -f $ghostty ]] && ! grep -q 'current/font.conf' "$ghostty"; then
  pending=true
  echo "  your Ghostty config does not load the font omacos sets"
  echo "    omacos refresh config ghostty/config.ghostty"
fi
if [[ -f $bar ]] && ! grep -q 'current/font.sh' "$bar"; then
  pending=true
  echo "  your bar does not load it either"
  echo "    omacos refresh config sketchybar/sketchybarrc"
fi

if $pending; then
  # refresh replaces the file and keeps a .bak, which is fine for a config you
  # never touched and lossy for one you did. Worth checking before, not after.
  echo "  refresh replaces the file (keeping a .bak and showing the diff), so if"
  echo "  you have edited either one, move your lines to the local file first:"
  echo "    ~/.config/ghostty/local.ghostty      — never rewritten"
  echo "    ~/.config/omacos/aerospace.local.toml"
  echo "  then: omacos font set"
else
  echo "  omacos font set — pick from what you have"
fi
echo "  omacos app list font — eight Nerd Fonts, one command each"
