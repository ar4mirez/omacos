# Which app fills which job. Runs after the apps are installed and after
# local.env is seeded, so DEFAULT_BROWSER is both readable and satisfiable.
#
# Only the browser is set here: it is the one default macOS asks about with a
# dialog if nothing has answered, and the one the README promises. Everything
# else stays unset until you choose, so a menu row shows no tick rather than a
# guess made on your behalf.

if ! omacos-feature check apps 2>/dev/null; then
  skip "App layer off — no defaults to set"
  return 0 2>/dev/null || exit 0
fi

browser=$(
  # shellcheck source=/dev/null
  set +u; . "$OMACOS_CONFIG/local.env" >/dev/null 2>&1 || true
  printf '%s' "${DEFAULT_BROWSER:-}"
)

if [[ -z $browser ]]; then
  skip "No DEFAULT_BROWSER in local.env — set one with: omacos default browser <name>"
elif [[ ! -d "/Applications/$browser.app" ]]; then
  skip "$browser is not installed — set the default with: omacos default browser <name>"
elif omacos-setup-browser "$browser" >/dev/null 2>&1; then
  ok "Default browser: $browser"
else
  warn "Could not set $browser as the default browser"
fi
