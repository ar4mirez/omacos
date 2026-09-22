step_heading "Theme"

if have omacos-theme-set; then
  current=$(cat "$OMACOS_STATE/current/theme.name" 2>/dev/null || echo "")
  omacos-theme-set "${current:-tokyo-night}"
else
  skip "Theme engine not installed yet"
fi
