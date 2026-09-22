echo "Rebuild the AeroSpace keymap so new bindings take effect"

# Idempotent: regenerating from keymap.conf always produces the same file.
if omacos-feature check desktop 2>/dev/null && command -v omacos-keymap-build >/dev/null; then
  omacos-keymap-build
fi
