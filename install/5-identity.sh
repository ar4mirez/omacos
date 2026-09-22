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
else
  warn "1Password SSH agent off — enable it in 1Password > Settings > Developer"
fi
