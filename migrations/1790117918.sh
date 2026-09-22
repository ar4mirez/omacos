echo "Bring the Mac closer to Omarchy: snapshots, alt-q, a clickable bar"

# Three things arrived at once, and two of them live in files that are yours
# and are never rewritten. So this migration applies what omacos owns and
# names what it cannot touch, rather than editing your config behind you.

# --- what omacos owns -------------------------------------------------------

# "No desktop icons", and a wallpaper that is not a button. Both only make
# sense with the tiling layer on: without it, the desktop is still a desktop.
if omacos-feature check desktop 2>/dev/null; then
  # Runs under `bash -euo pipefail`, so every step that is allowed to fail
  # says so: a `defaults write` macOS declines must not strand the queue.
  changed=false
  if [[ $(defaults read com.apple.finder CreateDesktop 2>/dev/null) != 0 ]]; then
    if defaults write com.apple.finder CreateDesktop -bool false 2>/dev/null; then
      changed=true
      echo "  desktop icons are hidden (~/Desktop is untouched)"
    fi
  fi
  if [[ $(defaults read com.apple.WindowManager EnableStandardClickToShowDesktop 2>/dev/null) != 0 ]]; then
    if defaults write com.apple.WindowManager EnableStandardClickToShowDesktop -bool false 2>/dev/null; then
      changed=true
      echo "  clicking the wallpaper no longer sweeps your tiles aside"
    fi
  fi
  if $changed; then killall Finder WindowManager 2>/dev/null || true; fi
fi

# --- what is yours ----------------------------------------------------------

# The keymap is the source of truth and this file never rewrites it. alt-q is
# new; say so, because nothing else on the machine would ever mention a
# binding that exists only in the shipped file.
keymap="${XDG_CONFIG_HOME:-$HOME/.config}/omacos/keymap.conf"
if [[ -f $keymap ]] && ! grep -q '^alt-q ' "$keymap"; then
  echo "  new: alt-q quits the app, where alt-w only closes a window"
  echo "       take it with: omacos refresh config omacos/keymap.conf"
fi

# Same for the bar: every item now answers left, right and middle clicks, and
# that lives in the seeded sketchybarrc.
bar="${XDG_CONFIG_HOME:-$HOME/.config}/sketchybar/sketchybarrc"
if [[ -f $bar ]] && ! grep -q 'click.sh' "$bar"; then
  echo "  new: the top bar takes left, right and middle clicks on every item"
  echo "       take it with: omacos refresh config sketchybar/sketchybarrc"
fi

echo "  new: omacos snapshot — omacos update now snapshots before it changes anything"
