echo "Stop the bar from sitting on top of your windows"

# macOS reserves no space for SketchyBar, so AeroSpace has been tiling
# underneath it. Regenerating is the whole fix; the gap now knows where the
# bar is.
if omacos-feature check desktop 2>/dev/null && command -v omacos-keymap-build >/dev/null; then
  omacos-keymap-build >/dev/null 2>&1 || echo "  run: omacos keymap build"
  position=$(omacos-bar position 2>/dev/null || echo top)
  echo "  the gap on the $position edge now leaves room for the bar (36pt of"
  echo "  every window was behind it)"
fi

echo "  new: omacos toggle padding — the terminal's inner margin, about three"
echo "       columns and a line per window"
