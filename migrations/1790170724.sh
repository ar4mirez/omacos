echo "Give the terminal its title bar back as pixels"

ghostty="${XDG_CONFIG_HOME:-$HOME/.config}/ghostty/config.ghostty"

if [[ -f $ghostty ]] && ! grep -q 'current/ghostty.conf' "$ghostty"; then
  echo "  a tiling window manager makes a title bar ~28pt of every window spent"
  echo "  on a name and three buttons alt-w already does, so omacos now hides it"
  echo "  take it with: omacos refresh config ghostty/config.ghostty"
  echo "  your own Ghostty settings belong in ~/.config/ghostty/local.ghostty,"
  echo "  which omacos never writes"
else
  echo "  omacos toggle titlebar — hide the terminal's title bar, or bring it back"
fi
