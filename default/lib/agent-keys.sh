# Shared helpers for working with SSH keys held in the 1Password agent.
# Sourced, never executed. Nothing here ever touches private key material:
# the agent only ever hands out public keys.

OMACOS_AGENT_SOCK="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
OMACOS_PUBKEY_DIR="$HOME/.ssh/omacos"

agent_is_live() { [[ -S $OMACOS_AGENT_SOCK ]]; }

agent_require() {
  agent_is_live && return 0
  echo "The 1Password SSH agent is not running." >&2
  echo "Enable it: 1Password > Settings > Developer > Use the SSH agent" >&2
  return 1
}

# Every public key the agent offers, one per line.
agent_keys() {
  SSH_AUTH_SOCK="$OMACOS_AGENT_SOCK" ssh-add -L 2>/dev/null | grep -v '^The agent'
}

# "ssh-ed25519 AAAA... My Key" -> "My Key"
key_name() { printf '%s' "${1#* * }"; }

key_fingerprint() { printf '%s\n' "$1" | ssh-keygen -lf - 2>/dev/null | awk '{print $2}'; }

# Accept a full public key, a 1Password item name, or a SHA256 fingerprint, so
# the same value works interactively and in a config file.
resolve_agent_key() {
  local want=$1 matches=() key
  [[ $want == ssh-* ]] && { printf '%s' "$want"; return 0; }
  while IFS= read -r key; do
    [[ -n $key ]] || continue
    if [[ $(key_name "$key") == "$want" || $(key_fingerprint "$key") == "$want" ]]; then
      matches+=("$key")
    fi
  done < <(agent_keys)

  case ${#matches[@]} in
    1) printf '%s' "${matches[0]}" ;;
    0) echo "No key in the agent matches: $want" >&2; return 1 ;;
    *) echo "Several keys are named \"$want\" — use a fingerprint instead:" >&2
       for key in "${matches[@]}"; do printf '  %s\n' "$(key_fingerprint "$key")" >&2; done
       return 1 ;;
  esac
}

# Let the user choose a key, showing the 1Password item name and a fingerprint
# rather than a wall of base64.
choose_agent_key() {
  local header=${1:-"Which key?"} keys=() labels=() key chosen i
  while IFS= read -r key; do [[ -n $key ]] && keys+=("$key"); done < <(agent_keys)
  ((${#keys[@]})) || { echo "No SSH keys in the agent." >&2; return 1; }
  ((${#keys[@]} == 1)) && { printf '%s' "${keys[0]}"; return 0; }

  for key in "${keys[@]}"; do
    labels+=("$(printf '%-24s %s' "$(key_name "$key")" "$(key_fingerprint "$key")")")
  done

  if command -v gum >/dev/null; then
    chosen=$(printf '%s\n' "${labels[@]}" | gum choose --header "$header") || return 1
  else
    echo "$header" >&2
    for i in "${!labels[@]}"; do printf '  %d) %s\n' "$((i + 1))" "${labels[i]}" >&2; done
    read -r -p "Number: " i
    [[ $i =~ ^[0-9]+$ ]] || { echo "Not a number." >&2; return 1; }
    chosen=${labels[$((i - 1))]:-}
  fi
  [[ -n ${chosen:-} ]] || return 1

  for i in "${!labels[@]}"; do
    [[ ${labels[i]} == "$chosen" ]] && { printf '%s' "${keys[i]}"; return 0; }
  done
  return 1
}

# ssh picks a specific agent key when pointed at its PUBLIC half, so writing
# these out is what makes per-identity key selection possible. Public only.
export_public_key() {
  local key=$1 slug
  slug=$(printf '%s' "$(key_name "$key")" | tr '[:upper:] ' '[:lower:]-' | tr -cd 'a-z0-9._-')
  mkdir -p "$OMACOS_PUBKEY_DIR"; chmod 700 "$OMACOS_PUBKEY_DIR"
  printf '%s\n' "$key" > "$OMACOS_PUBKEY_DIR/$slug.pub"
  chmod 644 "$OMACOS_PUBKEY_DIR/$slug.pub"
  printf '%s' "$OMACOS_PUBKEY_DIR/$slug.pub"
}

# IdentitiesOnly stops the agent from offering every key it holds and letting
# the server pick the first that works — which is how you end up pushing as the
# wrong account.
#
# The socket path contains a space ("Group Containers"), and ssh parses -o
# values itself: shell-escaping is not enough, the value has to carry quotes
# ssh can see, or it fails with "extra arguments at end of line".
ssh_command_for() {
  printf "ssh -o 'IdentityAgent=\"%s\"' -o IdentitiesOnly=yes -i %q" \
    "$OMACOS_AGENT_SOCK" "$1"
}
