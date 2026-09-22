# Tildes in this file appear inside messages shown to the user, where they
# are meant to stay literal rather than resolve to /Users/<name>.
# shellcheck disable=SC2088

step_heading "Config"

# Seed-if-absent, rather than a single global marker. A file you already have is
# never touched, and a config added in a later release still lands on update.
# To take a new shipped default deliberately: omacos refresh config <path>
seeded=0 kept=0
while IFS= read -r -d '' source_file; do
  relative=${source_file#"$OMACOS_PATH"/config/}
  target="${XDG_CONFIG_HOME:-$HOME/.config}/$relative"
  if [[ -e $target ]]; then
    kept=$((kept + 1))
    continue
  fi
  mkdir -p "$(dirname "$target")"
  cp "$source_file" "$target"
  seeded=$((seeded + 1))
done < <(find "$OMACOS_PATH/config" -type f -print0 2>/dev/null)

[[ $seeded -gt 0 ]] && ok "Seeded $seeded config file(s)"
[[ $kept -gt 0 ]] && skip "Kept $kept existing config file(s) — yours, untouched"

mkdir -p "$OMACOS_CONFIG"/{themes,themed,hooks,extensions,backgrounds} \
         "$OMACOS_STATE"/{current,migrations,done}

if [[ ! -f $OMACOS_CONFIG/local.env ]]; then
  cat > "$OMACOS_CONFIG/local.env" <<'LOCALENV'
# Personal settings. Never committed — omacos itself is a public repo.
# GIT_NAME="Your Name"
# GIT_EMAIL="you@example.com"
# WORK_DIR="$HOME/Work"

# Which 1Password SSH key signs your commits. Name it here and every machine
# you set up configures signing without asking. `omacos setup signing` writes
# this for you the first time you choose interactively.
# Use a SHA256 fingerprint instead of a name if two 1Password items share one.
# GIT_SIGNING_KEY="GitHub"

# Caps Lock is the easiest key to reach and does nothing useful. "option" makes
# it the omacos window-manager modifier, so Caps+1..6 and Caps+hjkl work under
# the left pinky. Also accepts control, command, escape.
# CAPSLOCK="option"

# Which app fills which job. `omacos default browser firefox` and
# `omacos default app music Spotify` write these for you; editing them by hand
# works just as well.
# DEFAULT_BROWSER="Brave Browser"
# DEFAULT_TERMINAL="Ghostty"
# DEFAULT_EDITOR="nvim"
# DEFAULT_AGENT="claude"

# The launcher roles the keymap binds — see `omacos default app` for the list.
# MUSIC_APP="Spotify"
# NOTES_APP="Obsidian"
# PASSWORD_APP="1Password"
LOCALENV
  ok "Created local.env (fill in your git identity)"
fi

# A fresh install has nothing to migrate from, so shipped migrations are
# recorded as already applied rather than replayed against a new machine.
if omacos-done ensure migrations-baseline 2>/dev/null; then
  omacos-migrate-mark-all
fi
omacos-done mark seed

# zsh reads ~/.zshenv first no matter what, so that is the one file that must
# live in $HOME. It exists only to point at ~/.config/zsh.
zshenv="$HOME/.zshenv"
if [[ ! -e $zshenv ]]; then
  cat > "$zshenv" <<'ZSHENV'
# Managed by omacos: everything else lives in ~/.config/zsh
export ZDOTDIR="$HOME/.config/zsh"
ZSHENV
  ok "Wrote ~/.zshenv (ZDOTDIR -> ~/.config/zsh)"
elif grep -q 'ZDOTDIR' "$zshenv"; then
  skip "~/.zshenv already sets ZDOTDIR"
else
  warn "~/.zshenv exists and does not set ZDOTDIR — add: export ZDOTDIR=\"\$HOME/.config/zsh\""
fi

# A pre-omacos ~/.zprofile stops being read once ZDOTDIR moves. Say so rather
# than silently dropping whatever was in it.
if [[ -f $HOME/.zprofile ]] && ! omacos-done check zprofile-notice 2>/dev/null; then
  warn "~/.zprofile is no longer read (ZDOTDIR moved). Its contents are now in ~/.config/zsh/.zprofile"
  omacos-done mark zprofile-notice
fi

# Agent skills: symlinked so updates improve them without re-running install.
omacos-finalize-user | sed 's/^/      /'
