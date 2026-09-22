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

### The trust rule

A theme directory containing `.git` came from someone else. Staging then drops
everything that can execute — `sketchybar.sh`, `*.lua`, terminal configs — and
regenerates it from the palette. Symlinks are never followed at any depth,
because that is how an `unlock.png` becomes a copy of any file your session can
read.

> Installing someone's theme should change what your desktop looks like, never
> what it runs.

CI fails if a new template is added without being classified.

## Keymap

`~/.config/omacos/keymap.conf` is the source of truth; `aerospace.toml` is
generated from it. AeroSpace's TOML cannot carry descriptions, so a keymap
written directly into it cannot produce a cheatsheet. Writing it once, in a
format that carries a description per binding, gives both.

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
