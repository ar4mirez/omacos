# ~/.config/zsh/.zshrc — this file is YOURS.
#
# omacos seeded it once and will never overwrite it. To take a newer version
# deliberately:  omacos refresh config zsh/.zshrc
#
# Everything omacos provides lives in the file sourced below, so you can read
# it, and you can turn parts of it off with the OMACOS_* switches above it.

# Set any of these to false before the source line to opt out:
#   OMACOS_ALIASES=false      shell aliases (ls -> eza, cat -> bat, ...)
#   OMACOS_KEYBINDINGS=false  line-editor keybindings
#   OMACOS_PROMPT=false       starship prompt
source "${OMACOS_PATH:-$HOME/.local/share/omacos}/default/zsh/omacos.zsh"

# Your overrides go below, or in these files. They load after omacos's defaults,
# so updates can improve the defaults without ever rewriting your choices.
[[ -f ~/.config/zsh/aliases.zsh ]] && source ~/.config/zsh/aliases.zsh
[[ -f ~/.config/zsh/local.zsh   ]] && source ~/.config/zsh/local.zsh
