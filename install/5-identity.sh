# Tildes in this file appear inside messages shown to the user, where they
# are meant to stay literal rather than resolve to /Users/<name>.
# shellcheck disable=SC2088

step_heading "Identity"

# shellcheck source=/dev/null
[[ -f $OMACOS_CONFIG/local.env ]] && . "$OMACOS_CONFIG/local.env"

if [[ -n ${GIT_NAME:-} && -n ${GIT_EMAIL:-} ]]; then
  git config --global user.name "$GIT_NAME"
  git config --global user.email "$GIT_EMAIL"
  ok "git identity: $GIT_NAME <$GIT_EMAIL>"
elif git config --global user.email >/dev/null 2>&1; then
  skip "git identity already set"
else
  warn "No git identity — set GIT_NAME and GIT_EMAIL in $OMACOS_CONFIG/local.env, then rerun"
fi

if have gh && ! gh auth status >/dev/null 2>&1; then
  warn "gh is not authenticated — run: gh auth login"
else
  have gh && ok "gh authenticated"
fi

op_sock="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
if [[ -S $op_sock ]]; then
  ok "1Password SSH agent is live"

  # Point ssh at the agent for every host. Keys stay in 1Password; nothing
  # private is written here, so this file is safe to keep in a dotfiles repo.
  ssh_config="$HOME/.ssh/config"
  mkdir -p "$HOME/.ssh"; chmod 700 "$HOME/.ssh"
  touch "$ssh_config"; chmod 600 "$ssh_config"
  if ! grep -q '2BUA8C4S2C.com.1password' "$ssh_config"; then
    printf '\n# Added by omacos: use the 1Password SSH agent for all hosts.\nHost *\n  IdentityAgent "%s"\n' \
      "$op_sock" >> "$ssh_config"
    ok "Pointed ~/.ssh/config at the 1Password agent"
  else
    skip "~/.ssh/config already uses the 1Password agent"
  fi

  # Signing is configured without a prompt when local.env names the key.
  if [[ $(git config --global gpg.format 2>/dev/null) == ssh ]]; then
    skip "Commit signing already configured"
  elif [[ -n ${GIT_SIGNING_KEY:-} ]]; then
    omacos-setup-signing | sed 's/^/      /'
  else
    warn "Commit signing not set up — run: omacos setup signing"
  fi
else
  warn "1Password SSH agent off — enable it in 1Password > Settings > Developer"
fi
