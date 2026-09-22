#!/usr/bin/env bash
# omacos installer. Idempotent: running it on a configured machine is a no-op.
set -euo pipefail

OMACOS_PATH="${OMACOS_PATH:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)}"
export OMACOS_PATH
# shellcheck source=/dev/null
. "$OMACOS_PATH/default/env-bootstrap"
export OMACOS_INSTALL="$OMACOS_PATH/install"

# shellcheck source=/dev/null
. "$OMACOS_INSTALL/helpers.sh"

steps=(
  1-preflight
  2-packages
  3-seed
  4-macos-defaults
  5-identity
  6-services
  7-theme
  8-defaults
)

for step in "${steps[@]}"; do
  run_step "$step"
done

omacos-hook post-install || true

printf '\n\033[1;32m omacos is installed.\033[0m\n\n'

# This shell started before ~/.zshenv existed, so it has no ZDOTDIR and none of
# the omacos PATH. Saying "open a new terminal" is easy to skip past; give the
# command that fixes the shell you are already in.
if ! command -v omacos >/dev/null 2>&1; then
  printf '  \033[1mReload your shell first\033[0m — this one predates the install:\n\n'
  printf '      \033[36mexec zsh -l\033[0m\n\n'
  printf '  Then:\n\n'
else
  printf '  Next:\n\n'
fi
printf '      \033[36momacos doctor\033[0m    what is set up, and what still needs you\n'
printf '      \033[36momacos\033[0m           every command, grouped\n\n'
