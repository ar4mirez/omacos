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
)

for step in "${steps[@]}"; do
  run_step "$step"
done

omacos-hook post-install || true

printf '\n\033[1;32m omacos is installed.\033[0m\n\n'
printf '  Next: open a new terminal, then run \033[1momacos doctor\033[0m\n'
printf '  Anything not yet set up is listed there with the command to fix it.\n\n'
