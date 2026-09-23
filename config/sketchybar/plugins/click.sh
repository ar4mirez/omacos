#!/usr/bin/env bash
# Clicks on a bar item. One script for every item, because the interesting
# part is the table, not the plumbing.
#
# sketchybar sets BUTTON to left, right or other (middle, and anything else a
# mouse has). The convention below is the same one the rest of omacos uses:
#
#   left    the obvious thing
#   right   where you would go to change it
#   middle  the next one along, or the menu behind it
#
# Called as `click.sh <item> [arg]`; NAME is sketchybar's own name for the item
# and is the fallback, so a copied line that forgets the argument still works.
# The workspace items pass their number as the argument, since one script
# serves all of them.

item=${1:-${NAME:-}}
arg=${2:-}

case "$item.${BUTTON:-left}" in
  # The workspace numbers are the one place on the bar where a click can move
  # a window as well as the eye, which is the whole alt / alt-shift ladder in
  # two buttons.
  space.left)      aerospace workspace "$arg" ;;
  space.right)     aerospace move-node-to-workspace --focus-follows-window "$arg" ;;
  space.*)         aerospace summon-workspace "$arg" ;;

  clock.left)      omacos-notice time ;;
  clock.right)     open 'x-apple.systempreferences:com.apple.Date-Time-Settings.extension' ;;
  clock.*)         omacos-launch-app calendar ;;

  battery.left)    omacos-notice battery ;;
  battery.right)   open 'x-apple.systempreferences:com.apple.Battery-Settings.extension' ;;
  battery.*)       omacos-toggle-idle ;;

  # The front app is the one thing on the bar that names a window, so its
  # clicks are the two things you do to a window.
  front_app.left)  omacos-menu apps ;;
  front_app.right) omacos-cmd-quit-app ;;
  front_app.*)     omacos-keymap-show --window ;;

  # Both of these only draw while something is running, so every click on them
  # means the same thing: stop it.
  recording.*)     omacos-capture-screenrecording --stop ;;
  idle.*)          omacos-toggle-idle off ;;

  # Reminders are the one indicator where "what are they?" is a fair question,
  # so left shows them and only right throws them away.
  reminders.left)  omacos-reminder list --window ;;
  reminders.right) omacos-reminder clear ;;
  reminders.*)     omacos-reminder ;;

  nightshift.*)    omacos-toggle-nightlight ;;

  # It only draws when there is something to do, so every button does it.
  update.*)        omacos-launch-tui "omacos-update" ;;

  theme.left)      omacos-theme-next ;;
  theme.right)     omacos-menu-theme ;;
  theme.*)         omacos-theme-background ;;

  *)               omacos-menu ;;
esac
