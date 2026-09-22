echo "Add the rest of Omarchy's basics: navigation, Focus, toggles, themes, apps"

# Idempotent throughout: a rebuilt keymap is byte-identical, and every branch
# below either reports or does nothing.

keymap="${XDG_CONFIG_HOME:-$HOME/.config}/omacos/keymap.conf"

if omacos-feature check desktop 2>/dev/null && command -v omacos-keymap-build >/dev/null; then
  # Rebuild first: the builder itself changed (it can emit TOML arrays now, and
  # it honours the gaps flag), so even an unchanged keymap wants regenerating.
  omacos-keymap-build >/dev/null || echo "  keymap build failed — run: omacos keymap build"

  # ~/.config is yours and is never rewritten, so a keymap from before this
  # release cannot contain what it added. Say what taking the new one gets you
  # rather than claiming bindings that are not reachable.
  if [[ -f $keymap ]] && ! grep -q 'omacos-launch-app' "$keymap"; then
    yours=$(grep -cE '^[a-z].*\|.*\|' "$keymap" 2>/dev/null || echo 0)
    echo "  your keymap has $yours bindings; omacos now ships 108"
    echo "  the new ones: window cycling, workspace next/prev, stacking, gaps,"
    echo "  Do Not Disturb, the browser URL, and apps bound by role"
    echo "  take them with: omacos refresh config omacos/keymap.conf"
  fi
fi

# Two of the themes shipped with a bat theme bat does not have, so BAT_THEME
# pointed at nothing. Fixed in the package tree; only worth a word if the
# active theme was one of them.
active="${XDG_STATE_HOME:-$HOME/.local/state}/omacos/current/theme.name"
if [[ -f $active ]] && grep -qxE 'tokyo-night|rose-pine-dawn' "$active"; then
  echo "  reapplying $(cat "$active") — its bat theme was pointing at nothing"
  omacos-theme-set "$(cat "$active")" >/dev/null 2>&1 || true
fi

echo "  19 more themes are installed — see them with: omacos theme list"
