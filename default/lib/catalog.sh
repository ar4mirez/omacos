# The app catalog: one shipped data file, read by install, remove, the menu
# providers, role defaults and preinstalls. Sourced, never executed. Expects
# OMACOS_PATH, OMACOS_CONFIG and OMACOS_STATE to be set.
#
# default/apps.json is package-owned; ~/.config/omacos/extensions/omacos-apps.jsonc
# is yours. They merge the way the menu's two files merge — reuse an id and you
# replace only the fields you declare.

# JSONC: drop whole-line comments and end-of-line comments that follow
# whitespace, so a "//" inside a URL survives. Shared with `omacos menu`.
strip_jsonc() { sed -e 's|^[[:space:]]*//.*$||' -e 's|[[:space:]]//[[:space:]].*$||' "$1"; }

CATALOG_JSON=""

catalog_json() {
  [[ -n $CATALOG_JSON ]] && { printf '%s' "$CATALOG_JSON"; return 0; }
  local shipped="$OMACOS_PATH/default/apps.json"
  local extension="$OMACOS_CONFIG/extensions/omacos-apps.jsonc"
  if [[ -f $extension ]]; then
    CATALOG_JSON=$(jq -s '.[0] * .[1]' "$shipped" <(strip_jsonc "$extension"))
  else
    CATALOG_JSON=$(cat "$shipped")
  fi
  printf '%s' "$CATALOG_JSON"
}

catalog_field() {
  catalog_json | jq -r --arg k "$1" --arg f "$2" '.[$k][$f] // empty'
}

catalog_has() {
  local found
  found=$(catalog_json | jq -r --arg k "$1" 'has($k)')
  [[ $found == true ]]
}

# Every id, or every id in one category, in file order.
catalog_ids() {
  if (($#)); then
    catalog_json | jq -r --arg c "$1" 'to_entries[] | select(.value.category == $c) | .key'
  else
    catalog_json | jq -r 'keys_unsorted[]'
  fi
}

catalog_categories() {
  catalog_json | jq -r '[.[].category] | unique[]'
}

# An argument is a catalog id when it names one; otherwise it is whatever the
# caller was already accepting (a raw Homebrew cask, an installed app's name).
# Prints the id and succeeds, or prints nothing and fails.
catalog_resolve() {
  catalog_has "$1" && { printf '%s' "$1"; return 0; }
  return 1
}

# --------------------------------------------------------------- presence ---
#
# One snapshot answers every id. Per-row probing does not scale: the menu forks
# a shell per guard and `osascript -e 'id of app "X"'` costs ~80ms, so sixty
# catalog rows would make the menu take seconds to draw. Four cheap reads cover
# everything instead — Homebrew's two lists, the app directories, and PATH.
#
# `bundle` is deliberately not a presence probe: an mdfind per missing entry is
# exactly the per-row cost this avoids. It is here for `duti`, which needs a
# bundle id to register a handler.

CATALOG_PRESENT_TTL=60

_catalog_app_names() {
  local dir app
  for dir in /Applications "$HOME/Applications" /System/Applications; do
    [[ -d $dir ]] || continue
    for app in "$dir"/*.app; do
      [[ -e $app ]] || continue
      app=${app##*/}
      printf '%s\n' "${app%.app}"
    done
  done
}

_catalog_snapshot_build() {
  local casks formulae apps mas_ids id source package app command present
  casks=$'\n'$(brew list --cask -1 2>/dev/null)$'\n'
  formulae=$'\n'$(brew list --formula -1 2>/dev/null)$'\n'
  apps=$'\n'$(_catalog_app_names)$'\n'
  if command -v mas >/dev/null 2>&1; then
    mas_ids=$'\n'$(mas list 2>/dev/null | awk '{print $1}')$'\n'
  else
    mas_ids=$'\n'
  fi

  while IFS=$'\t' read -r id source package app command; do
    [[ -n $id ]] || continue
    present=0
    if [[ -n $app && $apps == *$'\n'"$app"$'\n'* ]]; then
      present=1
    elif [[ -n $command ]] && command -v "${command%% *}" >/dev/null 2>&1; then
      present=1
    else
      case $source in
        cask)    [[ -n $package && $casks == *$'\n'"$package"$'\n'* ]] && present=1 ;;
        formula) [[ -n $package && $formulae == *$'\n'"$package"$'\n'* ]] && present=1 ;;
        mas)     [[ -n $package && $mas_ids == *$'\n'"$package"$'\n'* ]] && present=1 ;;
        webapp|tui)
          # Bundles omacos wrote carry a marker; that is what makes them ours.
          [[ -f "$HOME/Applications/$app.app/Contents/Info.plist" ]] && present=1 ;;
      esac
    fi
    printf '%s\t%s\n' "$id" "$present"
  done < <(catalog_json | jq -r '
    to_entries[]
    | [ .key,
        (.value.source // ""),
        (.value.package // ""),
        (if (.value.source // "") == "webapp" or (.value.source // "") == "tui"
         then (.value.label // "") else (.value.app // "") end),
        (.value.command // "") ]
    | @tsv')
}

# `id<TAB>0|1` for every catalog id, from a snapshot no older than the TTL.
catalog_present_all() {
  local cache="$OMACOS_STATE/apps/present" age
  if [[ ${1:-} != --refresh && -s $cache ]]; then
    age=$(( $(date +%s) - $(stat -f %m "$cache" 2>/dev/null || echo 0) ))
    if ((age >= 0 && age < CATALOG_PRESENT_TTL)); then
      cat "$cache"
      return 0
    fi
  fi
  mkdir -p "$(dirname "$cache")"
  _catalog_snapshot_build > "$cache.$$"
  mv "$cache.$$" "$cache"
  cat "$cache"
}

# 0 installed, 1 missing, 2 unknown id.
catalog_present() {
  catalog_has "$1" || return 2
  local state
  state=$(catalog_present_all | awk -F'\t' -v id="$1" '$1 == id { print $2; exit }')
  [[ $state == 1 ]]
}
