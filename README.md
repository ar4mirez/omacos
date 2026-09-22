# omacos

[![CI](https://github.com/ar4mirez/omacos/actions/workflows/ci.yml/badge.svg)](https://github.com/ar4mirez/omacos/actions/workflows/ci.yml)

An omakase developer environment for macOS, in the spirit of
[Omarchy](https://github.com/omacom/omarchy).

One command to set up a new Mac. Opinionated defaults you can override without
forking. A single self-documenting CLI. Themes that repaint the whole machine.

```bash
curl -fsSL https://raw.githubusercontent.com/ar4mirez/omacos/main/boot.sh | bash
```

Requires macOS on Apple silicon.

## The boundary

> omacos owns `~/.local/share/omacos`. **You** own `~/.config`.

Config is seeded into `~/.config` once and then never touched again. Each seeded
file *includes* the package-owned defaults, so updates improve the defaults
without ever rewriting your choices. Generated state lives in
`~/.local/state/omacos`, which keeps `~/.config` clean enough to commit to your
own dotfiles repo.

```bash
omacos refresh config ghostty/config.ghostty   # take a newer default, with a diff
```

See [docs/architecture.md](docs/architecture.md) for why it works this way.

## Commands

```bash
omacos                       # grouped, self-documenting help
omacos commands --json       # machine-readable, for agents
omacos doctor                # what is actually true on this machine
omacos menu                  # everything, in one searchable menu

omacos theme list|set|next|current
omacos keymap show|build
omacos feature enable desktop | apps
omacos webapp install Linear https://linear.app
omacos setup signing            # git commit signing via 1Password
omacos git org add Acme         # per-org identity under ~/Work/Acme/
omacos install app slack zoom
omacos update
```

Adding a command means adding a file to `bin/` with a `# omacos:summary=`
comment. There is no registry to update.

## What you get

**Terminal** — zsh (via `ZDOTDIR`, so `$HOME` stays clean), starship, fzf, atuin,
zoxide, eza, bat, ripgrep, fd, lazygit, delta, mise, direnv, Ghostty, Neovim,
tmux, btop.

**Desktop** (opt-in) — AeroSpace tiling, SketchyBar, JankyBorders, driven by a
keymap that generates both the window manager config and its own cheatsheet.

**Apps** (opt-in) — a small, editable set of GUI applications in
`Brewfile.apps`, installed with one admin prompt for the whole batch rather
than one per `.pkg` cask. Ships Brave and sets it as the default browser,
which also gives `omacos webapp install` a real app window to work with.

**Themes** — one `colors.toml` per theme renders every app's colours, switches
macOS between light and dark, and sets the wallpaper. Ships tokyo-night,
catppuccin-mocha, and rose-pine-dawn.

## One identity per organisation

Repos live at `~/Work/<Org>/<Repo>`, and each organisation gets its own name,
email, signing key and **SSH key**, chosen by directory:

```bash
omacos git identity --key "GitHub"        # the default, everywhere else
omacos git org add Acme --email me@acme.com --key "Acme"
omacos git org list
```

The SSH key matters as much as the email. With several keys in the agent, ssh
offers them in order and the server takes the first that works — so you
silently push as whichever account happens to be first. Each identity pins its
key with `IdentitiesOnly`, so the wrong one is never offered.

## Caps Lock

```bash
omacos setup capslock option    # Caps Lock becomes the WM modifier
omacos setup capslock status
omacos setup capslock off
```

This uses `hidutil`, which is part of macOS — no kernel extension, nothing to
approve, nothing to break on an OS upgrade — and a login agent so it survives a
reboot. Since the keymap is built on `alt`, Caps Lock then reaches every window
command under your left pinky.

True hyper (⌘⌃⌥⇧ on one key) is not expressible in `hidutil` and needs
Karabiner-Elements plus its DriverKit extension. `omacos setup capslock hyper`
explains that trade rather than installing it behind your back.

## Escape hatches

Ordered cheapest to most drastic. You should never have to fork.

1. Edit the seeded file in `~/.config` — yours, never overwritten
2. Use the `*.local` sibling (`~/.config/zsh/local.zsh`, `local.ghostty`, …)
3. Turn off a class of defaults: `OMACOS_ALIASES=false`, `OMACOS_PROMPT=false`
4. `~/.config/omacos/hooks/<event>.d/` — extend update and theme events
5. `~/.config/omacos/extensions/omacos-menu.jsonc` — add or replace menu rows
6. `~/.config/omacos/themed/*.tpl` — theme an app omacos has never heard of
7. `~/.config/omacos/keymap.conf` — the keymap is yours; the WM config is generated

## Why the desktop layer is optional

macOS 27 shipped a week before this project started, and AeroSpace and
SketchyBar have barely been tested on it. So they sit behind
`omacos feature enable desktop | apps`, and nothing in the terminal layer depends on
them. A broken status bar should cost you a status bar, not a working machine.

## Development

```bash
./test/run.sh    # 51 tests, sandboxed — cannot touch your real home
./install.sh     # idempotent: a no-op on a configured machine
```

## Licence

MIT
