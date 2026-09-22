step_heading "Services"

if ! omacos-feature check desktop 2>/dev/null; then
  skip "Desktop layer off — nothing to start"
  return 0 2>/dev/null || true
else
  for service in aerospace borders sketchybar; do
    if have "$service" || [[ -d /Applications/AeroSpace.app ]]; then
      ok "$service present"
    else
      warn "$service not installed"
    fi
  done
  warn "AeroSpace needs Accessibility permission — grant it in System Settings > Privacy & Security"
fi
