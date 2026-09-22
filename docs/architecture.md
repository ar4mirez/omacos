# Architecture

## Three trees, three owners

| Path | Owner | Lifetime |
|---|---|---|
| `~/.local/share/omacos` | omacos | Replaced wholesale on update |
| `~/.config` | you | Seeded once, then never touched |
| `~/.local/state/omacos` | generated | Rebuilt on demand; safe to delete |

The split exists so `~/.config` stays clean enough to commit to your own
dotfiles repo. Nothing generated ever lands there.

## Inheritance by include, not symlink

Symlinking shipped config into `~/.config` means you cannot edit it without
either losing your edits on update or blocking the update. So instead, a config
is **copied once** and that copy *includes* the package-owned defaults:

```bash
# ~/.config/zsh/.zshrc — yours
source "$OMACOS_PATH/default/zsh/omacos.zsh"   # improves on update
[[ -f ~/.config/zsh/local.zsh ]] && source ~/.config/zsh/local.zsh
```

You own the outer file forever. omacos improves the inner one. Neither fights
the other.

`omacos update` seeds any config file that does not exist yet, so new configs
arrive automatically while existing ones stay untouched. To deliberately take a
newer version of a file you already have, `omacos refresh config <path>` backs
yours up and shows the diff.

## The dispatcher

`bin/omacos` scans the first 80 lines of every `bin/omacos-*` script for
`# omacos:` metadata and assembles a grouped CLI from it. Adding a command means
adding a file — no registry, no dispatch table.

`omacos commands --json` exists so agents can discover the CLI rather than
guessing at it.

## Theme engine

One `colors.toml` per theme. `default/themed/*.tpl` renders every app config
from it via awk. `omacos theme set`:

1. Stages into `next-theme/` (shipped theme, then your overlay)
2. Renders templates for anything not hand-written
3. Atomically swaps `next-theme` → `current/theme`
4. Applies macOS appearance and wallpaper
5. Fans out `post_theme_commands` in parallel

Adding an app to the theme system means one template plus one line in that list.

Two environment escape hatches: `OMACOS_THEME_SKIP_BACKGROUND=1` leaves the
wallpaper alone, and `OMACOS_DRY_RUN=1` makes the wallpaper setter report what
it would do. The test suite uses both, which is how it exercises the full theme
path without repainting the machine it runs on.

Wallpapers are cached under `~/.local/state/omacos/wallpapers` under a
content-hashed filename. macOS caches wallpapers *by path*, so reusing one path
for changed content is a silent no-op — and hashing contents rather than mtime
keeps staging (which re-copies the file every switch) from leaking a new cache
entry each time.

### The trust rule

A theme directory containing `.git` came from someone else. Staging then drops
everything that can execute — `sketchybar.sh`, `*.lua`, terminal configs — and
regenerates it from the palette. Symlinks are never followed at any depth,
because that is how an `unlock.png` becomes a copy of any file your session can
read.

> Installing someone's theme should change what your desktop looks like, never
> what it runs.

CI fails if a new template is added without being classified.

## The native helper

OCR and the colour picker are a few lines of AppKit and have no CLI on macOS.
The Xcode Command Line Tools are already a hard requirement of the install, so
`default/swift/omacos-helper.swift` is compiled on demand into
`~/.local/state/omacos/bin` rather than pulling a second OCR engine and its
language data from Homebrew. It is rebuilt whenever the source is newer, which
is what makes `omacos update` and `omacos dev link` pick up a change without
anyone remembering to.

The same binary watches the pasteboard. NSPasteboard posts no change
notification, so watching it means polling — inside one long-lived process that
costs a `changeCount` read twice a second, rather than a shell and an
`osascript` per tick.

It skips anything carrying `org.nspasteboard.ConcealedType` or its siblings,
the convention password managers set for exactly this reason.

> A clipboard history that records the concealed types is a password log.

## Keymap

`~/.config/omacos/keymap.conf` is the source of truth; `aerospace.toml` is
generated from it. AeroSpace's TOML cannot carry descriptions, so a keymap
written directly into it cannot produce a cheatsheet. Writing it once, in a
format that carries a description per binding, gives both.

## The app catalog

`default/apps.json` is one file with five readers: the Install menu, the Remove
menu, presence checks, `omacos default <role>`, and the preinstall set. Omarchy
writes its equivalent out by hand — around 130 menu rows, plus a preinstall
list duplicated across two scripts with a comment warning that the two must
track each other. One data file avoids all of that, and a dotted id whose
prefix *is* its category means a new entry needs no menu row at all.

Two consequences shaped the design:

**Nothing is generated into `OMACOS_PATH`.** That rules out compiling catalog
entries into `default/menu.json`, which is why `bin/omacos-menu` grew a
`provider` field instead: a submenu can name a command that prints its rows.
Install, Remove, Defaults and the installed-apps list all use one.

**Presence has to be answered in bulk.** The menu forks a shell per guard, and
`osascript -e 'id of app "X"'` costs about 80ms — sixty rows across Install and
Remove would take seconds to draw. So `catalog_present_all` answers every id
from one `brew list --cask`, one `brew list --formula`, one scan of the
application directories and one `command -v` sweep, cached for a minute in
`~/.local/state/omacos/apps/present`. A catalog entry's `bundle` id is
deliberately *not* a presence probe — an `mdfind` per missing entry is exactly
the per-row cost this avoids — it is there for `duti`, which needs one to
register a URL handler.

## Bundles omacos writes

`omacos webapp install` and `omacos tui install` both build a real `.app` in
`~/Applications`, because that is the only place a bundle can live and still
exist for Launch Services. That is your directory, so the boundary is a marker:
every bundle omacos writes carries a `CFBundleIdentifier` of
`com.omacos.webapp.<slug>` or `com.omacos.tui.<slug>`, and nothing without one
is ever removed.

Two things macOS does differently from the `.desktop` files Omarchy generates:

**A URL scheme cannot reach a shell script.** macOS delivers a URL to an app as
a `GURL` Apple Event, not as an argument, so a script bundle never sees it. A
web app that claims a scheme is therefore built with `osacompile` as an
AppleScript applet whose `on open location` handler shells out to a normal
script — which is how a `mailto:` link reaches HEY's compose URL.

**Window rules match a title, not an app.** A terminal app floats or tiles by
whether its window title contains `omacos`, which is what `default/aerospace/
base.toml` matches on and what `omacos launch tui` sets. Web apps get no such
rule: a Chromium `--app=` window belongs to the browser's bundle id and its
title is the page title, so there is nothing stable to match.

## Migrations

`migrations/<unix-timestamp>.sh`, mode `0644`, no shebang, run with
`bash -euo pipefail`, strictly ordered, and required to be idempotent. The
timestamp comes from the last commit's date rather than `date +%s`, so ordering
follows git history and two branches cannot collide.

One marker per migration in `~/.local/state/omacos/migrations/`. A fresh install
pre-marks everything shipped, so new machines never replay history. The runner
hands the queue to each migration on a closed file descriptor, so a migration
cannot consume its own queue.

## Why the desktop layer is optional

macOS 27 shipped a week before this project started. SketchyBar's macOS 27
tracking issue had no test results; AeroSpace had no macOS 27 issue at all and
is pre-1.0. So AeroSpace, SketchyBar and JankyBorders sit behind
`omacos feature enable desktop`, and nothing in the terminal layer depends on
them. A broken status bar should cost you a status bar.

## Working on omacos itself

Two trees, on purpose:

| | |
|---|---|
| `~/Work/<you>/omacos` | the working checkout you edit and push from |
| `~/.local/share/omacos` | the installed tree, exactly as an end user has it |

Keeping the installed tree a plain clone of the remote means you use omacos the
way everyone else does — `omacos update` really does pull, migrate, re-seed and
reload. Developing directly in `~/.local/share/omacos` hides that whole path
from you, which is where the interesting bugs live.

The normal loop is therefore the same one a user is on:

```bash
cd ~/Work/<you>/omacos
# edit, ./test/run.sh, commit, push
omacos update          # the installed tree pulls it, like any machine
```

When that round trip is too slow to iterate against, point omacos at the
checkout instead:

```bash
omacos dev link ~/Work/<you>/omacos   # edits take effect immediately
omacos dev status                     # which tree am I running?
omacos dev unlink                     # back to the installed tree
```

`dev link` writes `~/.config/omacos/path.conf`, which `default/env-bootstrap`
reads before anything else. Three things follow it, and they have to move
together or "edits take effect immediately" is only partly true:

- **`bin/`**, via `PATH`.
- **The zsh layer.** `~/.config/zsh/.zshrc` has to name a tree before
  `OMACOS_PATH` exists, so it always reaches for the installed one;
  `default/zsh/omacos.zsh` hands off to the linked copy once bootstrap has
  resolved the real tree.
- **The agent-skill symlinks**, so an assistant reads the code you are editing.

A checkout is an ordinary directory — it can be renamed, deleted, or live on a
volume that is not mounted yet. If the linked tree is gone, bootstrap falls back
to the installed one and says so once. It has to: without that, `OMACOS_PATH`
points at nothing, `bin/` never reaches `PATH`, and `omacos dev unlink` — the
one command that would undo it — is itself unreachable. `doctor` and
`dev status` both report the link they are ignoring.

`dev status` names the checkout in either mode. The path is recorded when you
link and kept after you unlink, because unlinked is the normal state and
"where do I edit?" is the question asked from it.

Under the `~/Work/<Org>/<Repo>` convention the checkout also picks up that
organisation's git identity, so omacos commits are signed with the key that
account expects — see `omacos git org add`.
