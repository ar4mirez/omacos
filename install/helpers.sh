# Shared helpers for install leaves. Sourced, never executed.

_step_n=0
_step_total=7

step_heading() {
  _step_n=$((_step_n + 1))
  printf '\n\033[1;34m[%d/%d]\033[0m \033[1m%s\033[0m\n' "$_step_n" "$_step_total" "$1"
}

run_step() {
  local file="$OMACOS_INSTALL/$1.sh"
  [[ -f $file ]] || { printf '\033[31mMissing install step: %s\033[0m\n' "$file" >&2; return 1; }
  # Leaves are sourced so they share one shell (and one sudo timestamp).
  # shellcheck source=/dev/null
  . "$file"
}

say()  { printf '      %s\n' "$1"; }
ok()   { printf '      \033[32m✓\033[0m %s\n' "$1"; }
skip() { printf '      \033[2m· %s\033[0m\n' "$1"; }
warn() { printf '      \033[33m!\033[0m %s\n' "$1"; }

have() { command -v "$1" >/dev/null 2>&1; }

# Write a default only if it differs, so reruns are silent and we can tell
# whether macOS actually accepted the key.
set_default() {
  local domain=$1 key=$2 type=$3 value=$4 write_value=$4 current
  # `defaults write -bool` rejects 0/1 — it wants true/false — but `defaults
  # read` returns 0/1. Write one spelling, compare the other.
  if [[ $type == bool ]]; then
    [[ $value == 1 || $value == true || $value == yes ]] && { write_value=true; value=1; } \
                                                        || { write_value=false; value=0; }
  fi

  current=$(defaults read "$domain" "$key" 2>/dev/null) || current=""
  if [[ $current == "$value" ]]; then
    skip "$domain $key already $value"
    return 0
  fi

  if ! defaults write "$domain" "$key" "-$type" "$write_value" 2>/dev/null; then
    warn "$domain $key rejected by macOS"
    return 0
  fi

  current=$(defaults read "$domain" "$key" 2>/dev/null) || current=""
  if [[ $current == "$value" ]]; then
    ok "$domain $key = $value"
  else
    # A meaningful fraction of widely-copied `defaults write` lines silently
    # no-op on current macOS. Say so rather than pretending it worked.
    warn "$domain $key did not take (wanted $value, read '${current:-unset}')"
  fi
}
