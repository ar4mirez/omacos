# omacos core — the terminal environment.
#
# Everything here is safe on any macOS version and has no dependency on the
# window manager or status bar. `brew bundle --file Brewfile` should leave you
# with a working developer machine even if the desktop layer is off.

# bash 5: macOS still ships 3.2, which has no associative arrays.
brew "bash"
brew "coreutils"

# Shell surface
brew "starship"
brew "fzf"
brew "zoxide"
brew "atuin"
brew "direnv"
brew "mise"

# Files and search
brew "ripgrep"
brew "fd"
brew "eza"
brew "bat"
brew "tree"

# Git
brew "git"
brew "gh"
brew "lazygit"
brew "git-delta"

# Editor and multiplexing
brew "neovim"
brew "tree-sitter-cli"   # LazyVim's treesitter needs the CLI to build parsers
brew "tmux"

# System
brew "btop"
# Notifications with their own bundle id, so reminders and notices can be
# allowed or silenced as "omacos" rather than as Script Editor.
brew "terminal-notifier"
brew "wallpaper"   # sindresorhus/macos-wallpaper: the reliable wallpaper setter

# Scripting toolkit — gum drives the omacos menu
brew "gum"
brew "jq"
brew "yq"
brew "mas"
brew "duti"             # sets URL scheme handlers for `omacos setup browser`
brew "tldr"                 # the examples, without three screens of history
brew "yt-dlp"               # download a video from a page
brew "try"                  # date-stamped experiment directories, in ~/Work/tries
brew "fswatch"              # rsw: the macOS answer to inotifywait
brew "shellcheck"

cask "ghostty"
cask "1password-cli"
cask "font-jetbrains-mono-nerd-font"
