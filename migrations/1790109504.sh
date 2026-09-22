echo "Add the app catalog: install, remove, and which app fills which job"

# Idempotent throughout: a rebuilt keymap is byte-identical, and every branch
# below either reports or does nothing.

keymap="${XDG_CONFIG_HOME:-$HOME/.config}/omacos/keymap.conf"

if omacos-feature check desktop 2>/dev/null && command -v omacos-keymap-build >/dev/null; then
  omacos-keymap-build >/dev/null || echo "  keymap build failed — run: omacos keymap build"

  # ~/.config is yours and is never rewritten, so a keymap from before this
  # release cannot contain the new bindings. Name them rather than claiming
  # keys that are not actually reachable.
  if [[ -f $keymap ]] && ! grep -q 'omacos-launch-agent' "$keymap"; then
    echo "  four new app bindings: Photos, Maps, composing an email, and your coding agent"
    echo "  take them with: omacos refresh config omacos/keymap.conf"
  fi
fi

echo "  omacos install and omacos remove now browse a catalog of apps"
echo "  omacos default browser|terminal|editor|agent says which one you want"
echo "  see what is there with: omacos app list"
