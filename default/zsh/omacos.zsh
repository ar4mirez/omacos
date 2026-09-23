# omacos zsh defaults — package-owned. Do not edit; your changes are lost on
# update. Override in ~/.config/zsh/local.zsh instead.

source "${OMACOS_PATH:-$HOME/.local/share/omacos}/default/env-bootstrap"

# ~/.config/zsh/.zshrc has to name a tree before OMACOS_PATH exists, so it
# always reaches for the installed one — even while `omacos dev link` is in
# effect. env-bootstrap has just resolved the real tree; if that is a checkout,
# the shell layer being edited lives there, not here. Hand off once, so a
# linked tree owns this file too and not just bin/.
if [[ -z ${_OMACOS_ZSH_HANDOFF:-} ]]; then
  _omacos_zsh_linked="${OMACOS_PATH%/}/default/zsh/omacos.zsh"
  if [[ -r $_omacos_zsh_linked && ${_omacos_zsh_linked:A} != ${${(%):-%x}:A} ]]; then
    typeset -g _OMACOS_ZSH_HANDOFF=1
    source "$_omacos_zsh_linked"
    unset _OMACOS_ZSH_HANDOFF _omacos_zsh_linked
    return
  fi
  unset _omacos_zsh_linked
fi

# ------------------------------------------------------------------ history ---
HISTFILE="${XDG_STATE_HOME:-$HOME/.local/state}/zsh/history"
mkdir -p "${HISTFILE:h}"
HISTSIZE=100000
SAVEHIST=100000
setopt SHARE_HISTORY HIST_IGNORE_ALL_DUPS HIST_IGNORE_SPACE HIST_REDUCE_BLANKS
setopt EXTENDED_HISTORY INC_APPEND_HISTORY

# ---------------------------------------------------------------- behaviour ---
setopt AUTO_CD AUTO_PUSHD PUSHD_IGNORE_DUPS
setopt INTERACTIVE_COMMENTS NO_BEEP
setopt GLOB_DOTS EXTENDED_GLOB

# --------------------------------------------------------------- completion ---
autoload -Uz compinit
# Regenerate the dump at most once a day; compinit on every shell is slow.
_omacos_zcompdump="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump"
mkdir -p "${_omacos_zcompdump:h}"
if [[ -n ${_omacos_zcompdump}(#qN.mh+24) ]]; then
  compinit -d "$_omacos_zcompdump"
else
  compinit -C -d "$_omacos_zcompdump"
fi

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/completions"

# -------------------------------------------------------------- keybindings ---
if [[ ${OMACOS_KEYBINDINGS:-true} == true ]]; then
  bindkey -e
  bindkey '^[[A' history-search-backward
  bindkey '^[[B' history-search-forward
  bindkey '^[[1;3D' backward-word     # opt-left
  bindkey '^[[1;3C' forward-word      # opt-right
  bindkey '^[^?' backward-kill-word
fi

# ------------------------------------------------------------------ aliases ---
if [[ ${OMACOS_ALIASES:-true} == true ]]; then
  if (( $+commands[eza] )); then
    alias ls='eza --group-directories-first'
    alias ll='eza -l --group-directories-first --git --time-style=relative'
    alias la='eza -la --group-directories-first --git --time-style=relative'
    alias lt='eza --tree --level=2 --group-directories-first'
  fi
  (( $+commands[bat] )) && alias cat='bat --paging=never'
  (( $+commands[rg] ))  && alias grep='rg'
  (( $+commands[lazygit] )) && alias lg='lazygit'
  (( $+commands[nvim] )) && { alias vim='nvim'; alias vi='nvim'; export EDITOR=nvim VISUAL=nvim; }
  # `omacos default editor` wins over the nvim default above. Read straight out
  # of local.env rather than sourcing it: this runs in every interactive shell,
  # and the one value wanted here does not justify running your whole file.
  # A GUI editor never reaches $EDITOR — it has no command on PATH to match, so
  # git will not open a window and block waiting for it mid-commit.
  _omacos_local_env="${OMACOS_CONFIG:-$HOME/.config/omacos}/local.env"
  if [[ -r $_omacos_local_env ]]; then
    _omacos_editor=$(sed -n 's/^[[:space:]]*\(export[[:space:]]\{1,\}\)\{0,1\}DEFAULT_EDITOR=//p' \
      "$_omacos_local_env" | head -1)
    _omacos_editor=${_omacos_editor//[\"\']/}
    if [[ -n $_omacos_editor ]] && (( $+commands[$_omacos_editor] )); then
      export EDITOR=$_omacos_editor VISUAL=$_omacos_editor
    fi
    unset _omacos_editor
  fi
  unset _omacos_local_env
  alias g='git'
  alias ..='cd ..'
  alias ...='cd ../..'
  alias reload='exec zsh'
fi

# ---------------------------------------------------------------- functions ---
# Omarchy's shell-function layer: compression, worktrees, tmux dev layouts,
# rsync watchers, SSH port forwarding and the reconnecting ssh wrapper.
# Guarded: a tree without the file is a broken install, and an error printed
# before every prompt is a worse way to find that out than `omacos doctor`.
_omacos_functions="${OMACOS_PATH:-$HOME/.local/share/omacos}/default/zsh/functions.zsh"
if [[ ${OMACOS_FUNCTIONS:-true} == true && -r $_omacos_functions ]]; then
  source "$_omacos_functions"
fi
unset _omacos_functions

# -------------------------------------------------------------------- tools ---
(( $+commands[starship] )) && [[ ${OMACOS_PROMPT:-true} == true ]] && eval "$(starship init zsh)"
(( $+commands[zoxide] ))  && eval "$(zoxide init zsh --cmd cd)"
(( $+commands[direnv] ))  && eval "$(direnv hook zsh)"
(( $+commands[mise] ))    && eval "$(mise activate zsh)"
(( $+commands[atuin] ))   && eval "$(atuin init zsh --disable-up-arrow)"
if (( $+commands[fzf] )); then
  source <(fzf --zsh) 2>/dev/null
  export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
fi

# -------------------------------------------------------------------- theme ---
# BAT_THEME, FZF_DEFAULT_OPTS and friends, regenerated by `omacos theme set`.
[[ -r ~/.local/state/omacos/current/theme/env.sh ]] && source ~/.local/state/omacos/current/theme/env.sh

# ---------------------------------------------------------------- 1Password ---
# The SSH agent is the only place keys live; nothing is written to ~/.ssh.
_omacos_op_sock="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
[[ -S $_omacos_op_sock ]] && export SSH_AUTH_SOCK="$_omacos_op_sock"
unset _omacos_op_sock

export LANG=${LANG:-en_US.UTF-8}
export PAGER=${PAGER:-less}
export LESS=${LESS:--FRX}
