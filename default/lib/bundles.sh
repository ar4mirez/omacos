# The .app bundles omacos writes into ~/Applications — web apps and TUI
# wrappers. Sourced, never executed.
#
# ~/Applications is your tree, and it is also the only place a .app can live
# and still exist for Launch Services. What keeps omacos out of your own apps
# is the marker: every bundle omacos writes carries a CFBundleIdentifier of
# com.omacos.webapp.<slug> or com.omacos.tui.<slug>, and nothing without one is
# ever removed.

BUNDLE_DIR="$HOME/Applications"

bundle_slug() { printf '%s' "$1" | tr '[:upper:] ' '[:lower:]-'; }

bundle_path() { printf '%s/%s.app' "$BUNDLE_DIR" "$1"; }

bundle_identifier() {
  local plist="$1/Contents/Info.plist"
  [[ -f $plist ]] || return 1
  /usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$plist" 2>/dev/null
}

# webapp, tui, or nothing at all when the bundle is not ours.
bundle_kind() {
  local id
  id=$(bundle_identifier "$1") || return 1
  case $id in
    com.omacos.webapp.*) printf 'webapp' ;;
    com.omacos.tui.*)    printf 'tui' ;;
    *)                   return 1 ;;
  esac
}

# Names of every bundle omacos wrote, optionally of one kind.
bundle_names() {
  local want=${1:-} app kind
  [[ -d $BUNDLE_DIR ]] || return 0
  for app in "$BUNDLE_DIR"/*.app; do
    [[ -d $app ]] || continue
    kind=$(bundle_kind "$app") || continue
    [[ -n $want && $kind != "$want" ]] && continue
    app=${app##*/}
    printf '%s\n' "${app%.app}"
  done
}

# The URL a web app points at. Recorded in Info.plist at install time; older
# bundles predate that key, so fall back to reading the launcher.
bundle_url() {
  local dir plist
  dir=$(bundle_path "$1")
  plist="$dir/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c 'Print :OMACOSWebappURL' "$plist" 2>/dev/null && return 0
  sed -n 's/.*--app="\([^"]*\)".*/\1/p;s/^exec open "\(http[^"]*\)".*/\1/p' \
    "$dir/Contents/MacOS/$1" 2>/dev/null | head -1
}

bundle_remove() {
  local name=$1 want=$2 dir kind
  dir=$(bundle_path "$name")
  [[ -d $dir ]] || { echo "No such app: $name" >&2; return 1; }
  kind=$(bundle_kind "$dir") || {
    echo "$name was not created by omacos — refusing to remove it" >&2; return 1; }
  [[ -n $want && $kind != "$want" ]] && {
    echo "$name is a $kind, not a $want" >&2; return 1; }
  # Let Launch Services forget it before the files go, or a stale entry keeps
  # answering for the bundle id — including for any scheme it registered.
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
    -u "$dir" >/dev/null 2>&1 || true
  rm -rf "$dir"
}

# ------------------------------------------------------------------ icons ---
#
# A site's own apple-touch-icon is usually 180px or better; a favicon service
# is a last resort that often returns 16px upscaled. Try them in that order, so
# the Dock gets something worth looking at.

bundle_download_icon() {
  local url=$1 dest=$2
  curl -fsL --max-time 10 -o "$dest" "$url" 2>/dev/null || return 1
  [[ -s $dest ]] || return 1
  [[ $(file -b --mime-type "$dest" 2>/dev/null) == image/* ]]
}

bundle_fetch_site_icon() {
  local site=$1 dest=$2 origin page href
  origin=$(sed -E 's|^(https?://[^/]+).*|\1|' <<<"$site")

  page=$(curl -fsL --max-time 5 "$site" 2>/dev/null | head -c 100000 | tr '\n' ' ') || page=""
  href=$(grep -oiE "<link[^>]*rel=[\"'][^\"']*apple-touch-icon[^\"']*[\"'][^>]*>" <<<"$page" \
         | grep -oiE "href=[\"'][^\"']+" | head -1 | sed -E "s/^href=[\"']//") || href=""

  case $href in
    http://*|https://*) ;;
    //*)  href="https:$href" ;;
    /*)   href="$origin$href" ;;
    ?*)   href="$origin/$href" ;;
  esac

  { [[ -n $href ]] && bundle_download_icon "$href" "$dest"; } ||
    bundle_download_icon "$origin/apple-touch-icon.png" "$dest" ||
    bundle_download_icon "https://www.google.com/s2/favicons?domain=${origin#*://}&sz=256" "$dest"
}

# Turn any image into the bundle's icon. Best effort throughout: an app with no
# icon still works, and refusing to install one over a missing favicon would be
# a poor trade.
bundle_set_icon() {
  local app_dir=$1 source=$2 work size
  [[ -s $source ]] || return 1
  work=$(mktemp -d)
  mkdir -p "$work/icon.iconset" "$app_dir/Contents/Resources"
  # `-s format png` matters: favicon services often return JPEG, sips keeps the
  # source format whatever the output extension says, and iconutil then refuses
  # the iconset without explaining why.
  for size in 16 32 128 256 512; do
    sips -s format png -z "$size" "$size" "$source" \
      --out "$work/icon.iconset/icon_${size}x${size}.png" >/dev/null 2>&1 || true
  done
  iconutil -c icns "$work/icon.iconset" -o "$app_dir/Contents/Resources/icon.icns" 2>/dev/null
  local status=$?
  rm -rf "$work"
  return $status
}

# An icon reference is a URL, a file you already have, or nothing at all — in
# which case the site is asked for its own.
bundle_apply_icon() {
  local app_dir=$1 reference=$2 site=$3 tmp status=1
  tmp=$(mktemp -d)/icon.png
  if [[ -f $reference ]]; then
    cp "$reference" "$tmp" && bundle_set_icon "$app_dir" "$tmp" && status=0
  elif [[ $reference == http*://* ]]; then
    bundle_download_icon "$reference" "$tmp" && bundle_set_icon "$app_dir" "$tmp" && status=0
  elif [[ -n $site ]]; then
    bundle_fetch_site_icon "$site" "$tmp" && bundle_set_icon "$app_dir" "$tmp" && status=0
  fi
  rm -rf "$(dirname "$tmp")"
  return $status
}

# --------------------------------------------------------------- creation ---

# A plain shell-script bundle: a launcher and an Info.plist naming it.
bundle_create() {
  local name=$1 identifier=$2 body=$3 url=${4:-}
  local dir; dir=$(bundle_path "$name")
  mkdir -p "$dir/Contents/MacOS" "$dir/Contents/Resources"

  printf '#!/bin/bash\n%s\n' "$body" > "$dir/Contents/MacOS/$name"
  chmod +x "$dir/Contents/MacOS/$name"

  cat > "$dir/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>$name</string>
  <key>CFBundleDisplayName</key><string>$name</string>
  <key>CFBundleIdentifier</key><string>$identifier</string>
  <key>CFBundleExecutable</key><string>$name</string>
  <key>CFBundleIconFile</key><string>icon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>OMACOSWebappURL</key><string>$url</string>
</dict>
</plist>
PLIST
  printf '%s' "$dir"
}

# A bundle that can be handed a URL. macOS delivers one to an app as a GURL
# Apple Event, never as an argument, so a shell script can never receive it —
# an AppleScript applet's `on open location` is the only thing that can. The
# applet does nothing but hand the URL to a normal script.
bundle_create_url_handler() {
  local name=$1 identifier=$2 handler=$3 schemes=$4 url=${5:-}
  local dir work scheme
  dir=$(bundle_path "$name")
  # osacompile will not create the containing directory, and on a fresh account
  # ~/Applications does not exist yet.
  mkdir -p "$BUNDLE_DIR"
  work=$(mktemp -d)

  cat > "$work/applet.applescript" <<APPLESCRIPT
on run
	do shell script quoted form of "$handler"
end run

on open location this_URL
	do shell script quoted form of "$handler" & " " & quoted form of this_URL
end open location
APPLESCRIPT

  rm -rf "$dir"
  # osacompile is chatty on stdout about re-signing; the caller is printing a
  # path, not a build log.
  osacompile -o "$dir" "$work/applet.applescript" >/dev/null 2>&1 || { rm -rf "$work"; return 1; }
  rm -rf "$work"

  local plist="$dir/Contents/Info.plist"
  # An applet's plist has no CFBundleIdentifier of its own, so Set has nothing
  # to set — and without the identifier the bundle carries no omacos marker,
  # which is what makes it ours to list and to remove.
  /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $identifier" "$plist" >/dev/null 2>&1 ||
    /usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string $identifier" "$plist" >/dev/null
  /usr/libexec/PlistBuddy -c "Add :OMACOSWebappURL string $url" "$plist" >/dev/null 2>&1 || true
  /usr/libexec/PlistBuddy -c 'Add :CFBundleURLTypes array' "$plist" >/dev/null
  /usr/libexec/PlistBuddy -c 'Add :CFBundleURLTypes:0 dict' "$plist" >/dev/null
  /usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLName string $identifier" "$plist" >/dev/null
  /usr/libexec/PlistBuddy -c 'Add :CFBundleURLTypes:0:CFBundleURLSchemes array' "$plist" >/dev/null
  local i=0
  for scheme in $schemes; do
    /usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes:$i string $scheme" "$plist" >/dev/null
    i=$((i + 1))
  done
  printf '%s' "$dir"
}

# Tell Launch Services the bundle is here, and hand it the schemes it claims.
# Without the registration a freshly written bundle can stay invisible until
# something else happens to rescan.
bundle_register() {
  local dir=$1 schemes=${2:-} identifier scheme
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
    -f "$dir" >/dev/null 2>&1 || true
  [[ -n $schemes ]] || return 0
  identifier=$(bundle_identifier "$dir") || return 0
  command -v duti >/dev/null || return 0
  for scheme in $schemes; do
    duti -s "$identifier" "$scheme" 2>/dev/null || true
  done
}
