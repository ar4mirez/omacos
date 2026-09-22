# Which app fills which job. Sourced by the `omacos default <role>` commands,
# never executed. Expects OMACOS_PATH, OMACOS_CONFIG and the catalog lib.
#
# Everything persists to ~/.config/omacos/local.env — your file, already the
# home of DEFAULT_BROWSER, and the one place to look when you want to know what
# this machine reaches for. Writes are a single-line upsert: the file keeps its
# comments and its shape, and setting a value it already has changes nothing.

LOCAL_ENV="$OMACOS_CONFIG/local.env"

local_env_get() {
  [[ -f $LOCAL_ENV ]] || return 0
  # A subshell, so sourcing your file cannot leak variables into ours.
  # shellcheck source=/dev/null
  ( set +u; . "$LOCAL_ENV" >/dev/null 2>&1 || true; printf '%s' "${!1:-}" )
}

local_env_set() {
  local key=$1 value=$2 current tmp line replaced=false
  current=$(local_env_get "$key")
  [[ $current == "$value" ]] && return 0
  mkdir -p "$(dirname "$LOCAL_ENV")"
  [[ -f $LOCAL_ENV ]] || : > "$LOCAL_ENV"
  tmp=$(mktemp)
  while IFS= read -r line || [[ -n $line ]]; do
    if [[ $line =~ ^[[:space:]]*(export[[:space:]]+)?"$key"= ]]; then
      # Only the first assignment survives; a duplicate is what this fixes.
      if ! $replaced; then
        printf '%s=%s\n' "$key" "$(printf '%q' "$value")" >> "$tmp"
        replaced=true
      fi
    else
      printf '%s\n' "$line" >> "$tmp"
    fi
  done < "$LOCAL_ENV"
  $replaced || printf '%s=%s\n' "$key" "$(printf '%q' "$value")" >> "$tmp"
  mv "$tmp" "$LOCAL_ENV"
}

# The catalog entry in <category> whose id ends in <name>, so `omacos default
# browser firefox` finds browser.firefox without the caller spelling the id.
default_entry_for() {
  local category=$1 name=$2 id
  for id in $(catalog_ids "$category"); do
    [[ ${id#*.} == "$name" ]] && { printf '%s' "$id"; return 0; }
  done
  return 1
}

default_choices() {
  local category=$1 id
  for id in $(catalog_ids "$category"); do printf '%s ' "${id#*.}"; done
}

# What a role resolves to: DEFAULT_ID (a catalog id, or empty) and
# DEFAULT_TARGET (the app name or command to record). Globals rather than
# stdout, because resolving can install — and an installer inside a command
# substitution has nowhere to print and no process left to relaunch.
DEFAULT_ID=""
DEFAULT_TARGET=""

default_resolve() {
  local role=$1 category=$2 value=$3
  DEFAULT_ID=""; DEFAULT_TARGET=""

  if DEFAULT_ID=$(default_entry_for "$category" "$value"); then
    DEFAULT_TARGET=$(catalog_field "$DEFAULT_ID" app)
    [[ -n $DEFAULT_TARGET ]] || DEFAULT_TARGET=$(catalog_field "$DEFAULT_ID" command)
    return 0
  fi

  DEFAULT_ID=""
  # Not everything worth choosing is in the catalog — Safari ships with the
  # machine, and you may have installed something by hand. Accept anything
  # already here, by app name or by command.
  if [[ -d /Applications/$value.app || -d /System/Applications/$value.app \
     || -d $HOME/Applications/$value.app ]] || command -v "$value" >/dev/null 2>&1; then
    DEFAULT_TARGET=$value
    return 0
  fi

  printf 'No such %s: %s\n' "$role" "$value" >&2
  printf 'Choices: %s\n' "$(default_choices "$category")" >&2
  printf '(or the name of any app already installed)\n' >&2
  return 1
}

# Install what was chosen, if it is missing. Without a terminal there is
# nowhere for a password prompt or a progress bar to go, so the whole command
# moves into one — the same relaunch `omacos install app` does, for the same
# reason. Called before anything is written, so an abandoned install leaves the
# old default in place.
default_ensure_installed() {
  local role=$1 value=$2
  [[ -n $DEFAULT_ID ]] || return 0
  catalog_present "$DEFAULT_ID" && return 0
  if [[ ! -t 0 ]]; then
    exec omacos-launch-tui \
      "omacos-default-$role $(printf '%q' "$value"); echo; read -n 1 -s -r -p 'Press any key to close'"
  fi
  omacos-install-app "$DEFAULT_ID"
}

default_announce() {
  omacos-cmd-notify "$1" "$2" >/dev/null 2>&1 || true
  printf '\033[32m%s\033[0m\n' "$2"
}

default_show() {
  local current; current=$(local_env_get "$1")
  # Silent when unset: omacos picks no default for you, so a menu row stays
  # unticked until you choose one.
  [[ -n $current ]] && printf '%s\n' "$current"
  return 0
}
