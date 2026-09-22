#!/usr/bin/env bash
# omacos bootstrap:
#   curl -fsSL https://raw.githubusercontent.com/ar4mirez/omacos/main/boot.sh | bash
set -euo pipefail

OMACOS_REPO="${OMACOS_REPO:-ar4mirez/omacos}"
OMACOS_REF="${OMACOS_REF:-main}"
OMACOS_PATH="${OMACOS_PATH:-$HOME/.local/share/omacos}"

printf '\n\033[1;34m  omacos\033[0m — an omakase developer environment for macOS\n\n'

if [[ $(uname -s) != Darwin || $(uname -m) != arm64 ]]; then
  echo "omacos targets macOS on Apple silicon." >&2; exit 1
fi

if ! xcode-select -p >/dev/null 2>&1; then
  echo "  Installing Xcode Command Line Tools (a dialog will open)…"
  xcode-select --install || true
  until xcode-select -p >/dev/null 2>&1; do sleep 5; done
fi

if [[ -d $OMACOS_PATH/.git ]]; then
  echo "  Updating existing checkout at $OMACOS_PATH"
  git -C "$OMACOS_PATH" pull --ff-only
else
  echo "  Cloning $OMACOS_REPO ($OMACOS_REF) into $OMACOS_PATH"
  mkdir -p "$(dirname "$OMACOS_PATH")"
  git clone --branch "$OMACOS_REF" "https://github.com/$OMACOS_REPO.git" "$OMACOS_PATH"
fi

exec bash "$OMACOS_PATH/install.sh"
