# omacos shell functions — package-owned. Do not edit; your changes are lost on
# update. Override or add your own in ~/.config/zsh/local.zsh, which is sourced
# after this file and therefore wins.
#
# This is Omarchy's shell-function layer, ported. Where the two systems differ
# on the tool, the macOS one is used and the comment says which: fswatch rather
# than inotifywait, diskutil rather than parted, and `ps` rather than
# `pgrep -a`, which on macOS does not mean what it means on Linux.
#
# Turn the whole layer off with OMACOS_FUNCTIONS=false in ~/.config/zsh/local.zsh.

# ------------------------------------------------------------------ helpers ---

# Which coding agent you chose, so the tmux layouts do not have to be told.
_omacos_agent() {
  local file="${OMACOS_CONFIG:-$HOME/.config/omacos}/local.env" value
  [[ -r $file ]] || return 1
  value=$(sed -n 's/^[[:space:]]*\(export[[:space:]]\{1,\}\)\{0,1\}DEFAULT_AGENT=//p' "$file" | head -1)
  value=${value//[\"\']/}
  [[ -n $value ]] && print -r -- "$value"
}

_omacos_need() {
  local tool=$1 hint=$2
  command -v "$tool" >/dev/null 2>&1 && return 0
  print -u2 "This needs $tool: $hint"
  return 1
}

# ------------------------------------------------------------- compression ---

# COPYFILE_DISABLE, or macOS tar writes an AppleDouble `._name` beside every
# entry and the archive is full of junk on any other machine.
compress() {
  (( $# >= 1 )) || { print -u2 "Usage: compress <file-or-directory>"; return 1 }
  local target=${1%/}
  COPYFILE_DISABLE=1 tar -czf "${target}.tar.gz" "$target" && print "${target}.tar.gz"
}

decompress() {
  (( $# >= 1 )) || { print -u2 "Usage: decompress <archive.tar.gz>"; return 1 }
  tar -xzf "$@"
}

# ----------------------------------------------------------- finding files ---

# fzf over the tree with a syntax-highlighted preview. `eff` opens what you pick.
ff() {
  _omacos_need fzf "brew install fzf" || return 1
  if command -v bat >/dev/null 2>&1; then
    fzf --preview 'bat --style=numbers --color=always {}' "$@"
  else
    fzf --preview 'cat {}' "$@"
  fi
}

eff() {
  local picked; picked=$(ff) || return
  [[ -n $picked ]] && "${EDITOR:-vi}" "$picked"
}

# ---------------------------------------------------------- git worktrees ---

# A worktree beside the repository, named <repo>--<branch>, so `gd` can work
# out what to remove from the directory name alone.
ga() {
  (( $# == 1 )) || { print -u2 "Usage: ga <branch>"; return 1 }
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
    print -u2 "Not a git repository."; return 1 }
  # Not `path`: in zsh that name is tied to $PATH, so assigning to it here
  # would empty PATH and the next command in this function would not be found.
  local branch=$1 base destination
  base=$(basename "$PWD")
  destination="../${base}--${branch}"
  git worktree add -b "$branch" "$destination" || return 1
  # mise trusts a config per directory, and a fresh worktree is a new one.
  command -v mise >/dev/null 2>&1 && mise trust "$destination" >/dev/null 2>&1
  cd "$destination" || return 1
}

gd() {
  local cwd worktree root branch
  cwd=$PWD
  worktree=$(basename "$cwd")
  root=${worktree%%--*}
  branch=${worktree#*--}
  # Refuse anywhere that is not one of ga's worktrees. Without this, running
  # `gd` in an ordinary checkout would offer to delete the checkout.
  [[ $root != "$worktree" ]] || {
    print -u2 "Not a worktree made by ga (expected a <repo>--<branch> directory)."; return 1 }

  if command -v gum >/dev/null 2>&1; then
    gum confirm "Remove worktree $worktree and branch $branch?" || return 0
  else
    local reply
    read -r "reply?Remove worktree $worktree and branch $branch? (y/N) "
    [[ $reply == [Yy]* ]] || return 0
  fi

  cd "../$root" || return 1
  git worktree remove "$cwd" --force || return 1
  git branch -D "$branch"
}

# ------------------------------------------------------- tmux dev layouts ---

_omacos_tmux_ready() {
  _omacos_need tmux "brew install tmux" || return 1
  [[ -n $TMUX ]] || { print -u2 "Start tmux first."; return 1 }
}

# Editor filling the top, a terminal along the bottom, agent down the right.
# Panes are targeted by id throughout: `-t` with no id splits whichever pane
# is active, which after the first split is no longer the one you meant.
tdl() {
  local dir=$PWD editor agent agent2 agent_pane agent2_pane
  agent=${1:-$(_omacos_agent)}
  agent2=${2:-}
  [[ -n $agent ]] || { print -u2 "Usage: tdl <agent> [second-agent] — or set one: omacos default agent"; return 1 }
  _omacos_tmux_ready || return 1
  editor=$TMUX_PANE

  tmux rename-window -t "$editor" "$(basename "$dir")"
  tmux split-window -v -l 15% -t "$editor" -c "$dir"
  agent_pane=$(tmux split-window -h -l 30% -t "$editor" -c "$dir" -P -F '#{pane_id}')

  if [[ -n $agent2 ]]; then
    agent2_pane=$(tmux split-window -v -t "$agent_pane" -c "$dir" -P -F '#{pane_id}')
    tmux send-keys -t "$agent2_pane" "$agent2" C-m
  fi

  tmux send-keys -t "$agent_pane" "$agent" C-m
  tmux send-keys -t "$editor" "${EDITOR:-nvim} ." C-m
  tmux select-pane -t "$editor"
}

# Four panes: editor, a watched diff, a terminal, and an agent.
tds() {
  _omacos_tmux_ready || return 1
  local dir=$PWD editor diff terminal agent_pane agent
  editor=$TMUX_PANE
  agent=${1:-$(_omacos_agent)}

  tmux rename-window -t "$editor" "$(basename "$dir")"
  terminal=$(tmux split-window -v -l 50% -t "$editor" -c "$dir" -P -F '#{pane_id}')
  diff=$(tmux split-window -h -l 50% -t "$editor" -c "$dir" -P -F '#{pane_id}')
  agent_pane=$(tmux split-window -h -l 50% -t "$terminal" -c "$dir" -P -F '#{pane_id}')

  tmux send-keys -t "$editor" "${EDITOR:-nvim} ." C-m
  # git itself, not a tool you may not have: --watch is what the pane is for.
  tmux send-keys -t "$diff" "git diff" C-m
  [[ -n $agent ]] && tmux send-keys -t "$agent_pane" "$agent" C-m
  tmux select-pane -t "$editor"
}

# One tdl window per subdirectory here — a session per group of projects.
tdlm() {
  # omacos sets GLOB_DOTS, under which `*` matches .git and friends — and the
  # (/) qualifier selects directories without undoing that. localoptions keeps
  # the change inside this function.
  setopt localoptions noglobdots
  local base=$PWD agent=${1:-$(_omacos_agent)} agent2=${2:-} first=1 dir pane
  [[ -n $agent ]] || { print -u2 "Usage: tdlm <agent> [second-agent]"; return 1 }
  _omacos_tmux_ready || return 1
  # tmux rejects . and : in a session name.
  tmux rename-session "$(basename "$base" | tr '.:' '--')"

  # (N) so an empty directory is nothing rather than a literal '*/', and (/)
  # so only directories match.
  for dir in "$base"/*(N/); do
    if (( first )); then
      tmux send-keys -t "$TMUX_PANE" "cd ${(q)dir} && tdl $agent $agent2" C-m
      first=0
    else
      pane=$(tmux new-window -c "$dir" -P -F '#{pane_id}')
      tmux send-keys -t "$pane" "tdl $agent $agent2" C-m
    fi
  done
}

# A grid of panes all running the same thing. Good for a swarm of agents.
tsl() {
  # What you typed is checked before where you are: "start tmux first" is not
  # the useful answer to someone who also left the arguments off.
  (( $# >= 2 )) || { print -u2 "Usage: tsl <pane-count> <command>"; return 1 }
  local count=$1 dir=$PWD pane
  shift
  local cmd=$*
  [[ $count == <-> ]] || { print -u2 "Pane count must be a number."; return 1 }
  _omacos_tmux_ready || return 1

  local -a panes=("$TMUX_PANE")
  tmux rename-window -t "$TMUX_PANE" "$(basename "$dir")"

  while (( ${#panes[@]} < count )); do
    pane=$(tmux split-window -h -t "${panes[-1]}" -c "$dir" -P -F '#{pane_id}') || break
    panes+=("$pane")
    tmux select-layout -t "${panes[1]}" tiled >/dev/null
  done

  for pane in "${panes[@]}"; do
    tmux send-keys -t "$pane" "$cmd" C-m
  done
  tmux select-pane -t "${panes[1]}"
}

# ---------------------------------------------------------- rsync watchers ---

# The marker is what lsw and dsw find the watcher by, so it has to stay in the
# process's own argv rather than only in ours.
_OMACOS_RSW_MARKER=omacos-rsw-watch

# Mirror a directory somewhere, then keep mirroring it on every change.
rsw() {
  (( $# == 2 )) || { print -u2 "Usage: rsw <source> <destination>"; return 1 }
  # inotifywait is Linux's; fswatch is the same idea on macOS and is the one
  # thing here that is not already installed.
  _omacos_need fswatch "brew install fswatch" || return 1
  local src=${1%/} dest=$2 sockets rsh
  [[ -d $src ]] || { print -u2 "No such directory: $src"; return 1 }

  # One SSH connection for the whole session, so 1Password asks once rather
  # than on every change.
  sockets="${TMPDIR:-/tmp}/omacos-ssh"
  mkdir -p "$sockets"
  rsh="ssh -o ControlMaster=auto -o ControlPath=$sockets/rsw-%r@%h:%p -o ControlPersist=yes"

  # macOS has no setsid; `&!` is zsh's background-and-disown, which is what
  # keeps the watcher alive after this shell exits.
  RSYNC_RSH=$rsh nohup zsh -c '
    rsync -a "$1/" "$2"
    fswatch -o -r "$1" | while read -r _; do rsync -a "$1/" "$2"; done
  ' "$_OMACOS_RSW_MARKER" "$src" "$dest" >/dev/null 2>&1 &!
  print "Watching $src -> $dest"
}

_omacos_rsw_processes() {
  ps -axo pid=,command= 2>/dev/null | grep -F "$_OMACOS_RSW_MARKER" | grep -v grep
}

lsw() {
  local line pid rest found=0
  while IFS= read -r line; do
    [[ -n $line ]] || continue
    pid=${line%% *}
    rest=${line##*$_OMACOS_RSW_MARKER }
    print "$pid: ${rest% *} -> ${rest##* }"
    found=1
  done < <(_omacos_rsw_processes)
  (( found )) || print "No active watches"
}

dsw() {
  local line pid found=0
  while IFS= read -r line; do
    [[ -n $line ]] || continue
    pid=${line%% *}
    # Children first: fswatch does not carry the marker, so killing only the
    # wrapper would leave it running and holding the pipe open.
    pkill -P "$pid" 2>/dev/null
    kill "$pid" 2>/dev/null && { print "Stopped watch (pid $pid)"; found=1 }
  done < <(_omacos_rsw_processes)
  (( found )) || print "No active watches"
}

# ---------------------------------------------------- ssh port forwarding ---

# Reach a remote port at localhost:<port>, which is what a browser needs before
# it will treat a dev server as a secure context.
fip() {
  (( $# >= 2 )) || { print -u2 "Usage: fip <host> <port> [port...]"; return 1 }
  local host=$1 port
  shift
  for port in "$@"; do
    if ssh -f -N -L "${port}:localhost:${port}" "$host"; then
      print "Forwarding localhost:$port -> $host:$port"
    fi
  done
}

dip() {
  (( $# >= 1 )) || { print -u2 "Usage: dip <port> [port...]"; return 1 }
  local port
  for port in "$@"; do
    if pkill -f "ssh.*-L ${port}:localhost:${port}" 2>/dev/null; then
      print "Stopped forwarding port $port"
    else
      print "No forwarding on port $port"
    fi
  done
}

lip() {
  # macOS pgrep -a is not Linux's "show the command line", so the listing comes
  # from ps and pgrep only supplies the pids.
  local pids
  pids=$(pgrep -f 'ssh.*-L [0-9]*:localhost:[0-9]*' 2>/dev/null) || true
  if [[ -z $pids ]]; then
    print "No active forwards"
    return 0
  fi
  ps -o pid=,command= -p ${=pids}
}

# -------------------------------------------------------- ssh reconnection ---

# A remote tmux or editor arms terminal modes over the SSH pipe — mouse
# tracking, focus reporting, the alternate screen — that only it can disarm. If
# the link dies instead of exiting cleanly they stay armed locally, and every
# mouse move floods the prompt with escape junk.
_omacos_ssh_disarm() {
  printf '\e[?1000l\e[?1002l\e[?1003l\e[?1006l\e[?1004l\e[?1049l\e[?25h'
}

# True for an interactive session: a destination, and no remote command. The
# letters are the ssh(1) options that take a value, so their arguments are not
# mistaken for the destination.
_omacos_ssh_interactive() {
  # Not `argv`: in zsh that name *is* the positional parameters.
  local -a given=("$@")
  local value_opts="BbcDEeFIiJLlmOoPpQRSWw"
  local arg letters dest="" opts_done="" i resolved

  while (( $# )); do
    arg=$1
    shift
    if [[ -z $opts_done && $arg == "--" ]]; then
      opts_done=1
    elif [[ -z $opts_done && $arg == -?* ]]; then
      letters=${arg#-}
      for (( i = 1; i <= ${#letters}; i++ )); do
        if [[ $value_opts == *${letters[i]}* ]]; then
          # Glued to the letter (-p2222) unless the letter ends the argument,
          # in which case it takes the next one (-p 2222).
          (( i == ${#letters} )) && shift
          break
        fi
      done
    elif [[ -z $dest ]]; then
      dest=$arg
    else
      return 1
    fi
  done
  [[ -n $dest ]] || return 1

  # A RemoteCommand from ssh_config replays on reconnect exactly like a
  # positional command would. `ssh -G` resolves the effective config for this
  # invocation without connecting. Fail closed: an undetected RemoteCommand
  # must not be replayed.
  resolved=$(command ssh -G "${given[@]}" 2>/dev/null) || return 1
  ! grep -i '^remotecommand ' <<<"$resolved" | grep -qvi '^remotecommand none$'
}

ssh() {
  local rc started=$SECONDS
  command ssh "$@"
  rc=$?

  [[ -t 1 ]] || return $rc
  _omacos_ssh_disarm

  # Reconnect only when an established interactive session drops. ssh exits 255
  # for transport failures, but a fast 255 is a connect or auth failure, a
  # remote command's own 255 is indistinguishable and must not be replayed, and
  # redirected stdin would feed the rest of the pipe to a fresh remote shell.
  if (( rc != 255 )) || [[ ! -t 0 ]] || ! _omacos_ssh_interactive "$@" ||
     (( SECONDS - started < 30 )); then
    return $rc
  fi

  # A subshell, so Ctrl-C reaches the whole foreground process group and stops
  # the loop as well as the attempt in flight.
  (
    while true; do
      print "Connection lost. Reconnecting (Ctrl-C to stop)..."
      sleep 2
      command ssh "$@"
      rc=$?
      _omacos_ssh_disarm
      (( rc != 255 )) && exit $rc
    done
  )
}

# ------------------------------------------------------------------ drives ---

# Every whole disk macOS considers external, so nothing here can be pointed at
# the disk you booted from.
_omacos_external_disks() {
  local disk
  for disk in $(diskutil list 2>/dev/null | sed -n 's|^/dev/\(disk[0-9]*\) .*(external.*|\1|p'); do
    print -r -- "/dev/$disk"
  done
}

_omacos_refuse_internal() {
  local device=$1
  [[ $device == /dev/disk<->  ]] || {
    print -u2 "Name a whole disk, like /dev/disk4 — not a partition."; return 1 }
  if ! _omacos_external_disks | grep -qx "$device"; then
    print -u2 "$device is not an external disk. Refusing."
    print -u2 "External disks right now:"
    _omacos_external_disks | sed 's/^/  /' || true
    return 1
  fi
}

# Format a whole external disk as one exFAT partition, which Windows, macOS and
# Linux all read.
format-drive() {
  if (( $# != 2 )); then
    print -u2 "Usage: format-drive <device> <name>"
    print -u2 "Example: format-drive /dev/disk4 'My Stuff'"
    print -u2 "\nExternal disks right now:"
    _omacos_external_disks | sed 's/^/  /' || print -u2 "  (none)"
    return 1
  fi
  _omacos_refuse_internal "$1" || return 1
  print "This erases everything on $1 and labels it '$2'."
  local reply
  read -r "reply?Continue? (y/N) "
  [[ $reply == [Yy]* ]] || return 0
  # diskutil does the partition table, the filesystem and the remount in one
  # step, and refuses on its own if the disk is busy.
  diskutil eraseDisk ExFAT "$2" MBRFormat "$1"
}

# Write an image to an external disk.
iso2sd() {
  if (( $# < 1 )); then
    print -u2 "Usage: iso2sd <image> <device>"
    print -u2 "\nExternal disks right now:"
    _omacos_external_disks | sed 's/^/  /' || print -u2 "  (none)"
    return 1
  fi
  (( $# == 2 )) || { print -u2 "Name the device too — see the list above."; return 1 }
  [[ -f $1 ]] || { print -u2 "No such file: $1"; return 1 }
  _omacos_refuse_internal "$2" || return 1
  print "This overwrites everything on $2 with $1."
  local reply
  read -r "reply?Continue? (y/N) "
  [[ $reply == [Yy]* ]] || return 0
  diskutil unmountDisk "$2" || return 1
  # /dev/rdiskN, not /dev/diskN: the raw device is unbuffered and many times
  # faster for a linear write like this one.
  sudo dd if="$1" of="${2/disk/rdisk}" bs=4m status=progress
  diskutil eject "$2"
}
