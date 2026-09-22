# ~/.config/zsh/.zprofile — yours. Login-shell setup.
#
# Note: once ZDOTDIR points here, zsh reads THIS file and no longer reads
# ~/.zprofile. omacos moves the Homebrew line here during install.

eval "$(/opt/homebrew/bin/brew shellenv zsh)"

[[ -f ~/.config/zsh/local.zprofile ]] && source ~/.config/zsh/local.zprofile
