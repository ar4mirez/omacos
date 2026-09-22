# Shared wallpaper selection and caching. Sourced by `omacos theme set` and
# `omacos theme background`, never executed. Expects OMACOS_STATE and
# OMACOS_CONFIG to be set.

# Every image a theme offers: the ones it ships, plus anything you dropped in
# ~/.config/omacos/backgrounds/<theme>/. NUL-separated, because a filename may
# contain anything but a NUL.
background_candidates() {
  local theme=$1
  find -L "$OMACOS_STATE/current/theme/backgrounds" "$OMACOS_CONFIG/backgrounds/$theme" \
    -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.heic' \) \
    -print0 2>/dev/null | sort -z
}

background_fingerprint() { shasum -a 256 "$1" | cut -c1-12; }

# macOS caches wallpapers by path, so writing the same path with new contents
# is a silent no-op. Every distinct image therefore gets a distinct, stable
# filename — hashed on contents, not mtime, because staging re-copies the file
# on every theme switch and an mtime would leak a cache entry each time.
apply_background() {
  local theme=$1 background=$2 cache target fingerprint
  cache="$OMACOS_STATE/wallpapers"
  mkdir -p "$cache" "$OMACOS_STATE/current"
  fingerprint=$(background_fingerprint "$background")
  target="$cache/${theme}-${fingerprint}.${background##*.}"
  if [[ ! -f $target ]]; then
    cp "$background" "$target"
    # Drop superseded wallpapers for this theme; the active one is kept.
    find "$cache" -maxdepth 1 -name "${theme}-*" ! -name "$(basename "$target")" -delete 2>/dev/null || true
  fi
  ln -sfn "$target" "$OMACOS_STATE/current/background"
  omacos-cmd-set-wallpaper "$target"
}
