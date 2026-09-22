# omacos

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
omacos feature enable desktop
omacos webapp install Linear https://linear.app
omacos setup signing            # git commit signing via 1Password
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

**Themes** — one `colors.toml` per theme renders every app's colours, switches
macOS between light and dark, and sets the wallpaper. Ships tokyo-night,
catppuccin-mocha, and rose-pine-dawn.

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
`omacos feature enable desktop`, and nothing in the terminal layer depends on
them. A broken status bar should cost you a status bar, not a working machine.

## Development

```bash
./test/run.sh    # 33 tests, sandboxed — cannot touch your real home
./install.sh     # idempotent: a no-op on a configured machine
```

## Licence

MIT
