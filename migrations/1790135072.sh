echo "Move the bar off the menu bar, restart a subsystem, notice a low battery"

bar="${XDG_CONFIG_HOME:-$HOME/.config}/sketchybar/sketchybarrc"
batt="${XDG_CONFIG_HOME:-$HOME/.config}/sketchybar/plugins/battery.sh"

if [[ -f $bar ]] && ! grep -q 'current/bar.sh' "$bar"; then
  echo "  your bar cannot be moved yet:"
  echo "    omacos refresh config sketchybar/sketchybarrc"
  echo "    omacos refresh config sketchybar/plugins/battery.sh"
  echo "    sketchybar --reload"
elif [[ -f $batt ]] && ! grep -q 'battery-low' "$batt"; then
  echo "  your battery plugin does not fire the battery-low hook yet"
  echo "    omacos refresh config sketchybar/plugins/battery.sh"
fi

# The two-bars problem is the thing people notice first and never have a name
# for, so say it here rather than waiting for them to run doctor.
menubar=$(defaults read NSGlobalDomain _HIHideMenuBar 2>/dev/null || echo 0)
if omacos-feature check desktop 2>/dev/null && [[ $menubar != 1 ]]; then
  echo "  macOS draws its menu bar across the top and so does omacos, which is"
  echo "  two rows up there. Either one fixes it:"
  echo "    omacos toggle menubar        hide Apple's"
  echo "    omacos bar position bottom   move ours"
fi

echo "  omacos restart wifi|bluetooth|audio — reload one thing, not the machine"
