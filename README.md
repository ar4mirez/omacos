# omacos

An omakase developer environment for macOS, in the spirit of [Omarchy](https://github.com/omacom/omarchy).

One command to set up a new Mac. Opinionated defaults you can override without
forking. A single self-documenting CLI. Themes that repaint the whole machine.

```bash
curl -fsSL https://raw.githubusercontent.com/ar4mirez/omacos/main/boot.sh | bash
```

## The boundary

> omacos owns `~/.local/share/omacos`. **You** own `~/.config`.

Config files are seeded into `~/.config` once and then never touched again.
Each seeded file *includes* the package-owned defaults, so updates can improve
the defaults without ever rewriting your choices. Generated state lives in
`~/.local/state/omacos`, which keeps `~/.config` clean enough to commit to your
own dotfiles repo.

To deliberately take a newer shipped default:

```bash
omacos refresh config ghostty/config.ghostty   # backs yours up and shows the diff
```

## Commands

```bash
omacos                    # grouped, self-documenting help
omacos commands --json    # machine-readable, for agents
omacos doctor             # what is actually true on this machine
omacos theme list|set|next|current
omacos feature enable desktop
```

## Status

Built in phases. Working today: the CLI, install flow, macOS defaults, the shell
and git layers, and the theme engine with three themes. The desktop layer
(AeroSpace, SketchyBar, JankyBorders) is opt-in via `omacos feature enable desktop`.

## Licence

MIT
