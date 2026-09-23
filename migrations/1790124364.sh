echo "Add the shell-function layer: worktrees, tmux layouts, watchers, ssh"

# Nothing to migrate: default/zsh/functions.zsh is package-owned and is sourced
# by the shell layer, so it is live in the next shell you open. fswatch comes
# from the Brewfile, which `omacos update` has already run by this point.
#
# Worth saying out loud, though, because a set of functions that simply appears
# is a set of functions nobody knows to type.

echo "  new in any new shell:"
echo "    ga / gd          a git worktree beside the repo, and back again"
echo "    tdl / tds / tsl  tmux dev layouts around your default agent"
echo "    rsw / lsw / dsw  mirror a directory somewhere on every change"
echo "    fip / dip / lip  forward a remote port to localhost"
echo "    compress / ff    and an ssh that reconnects when a session drops"
echo "  all of them: omacos docs, or docs/shell-functions.md"

if ! command -v fswatch >/dev/null 2>&1; then
  # rsw is the only one with a dependency, and a missing one is a function that
  # looks broken rather than one that tells you what it needs.
  echo "  note: rsw needs fswatch — run: brew install fswatch"
fi
