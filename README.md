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

See [docs/architecture.md](docs/architecture.md) for why it works this way,
[docs/coming-from-macos.md](docs/coming-from-macos.md) for what changes on a Mac
you already know how to use, and [docs/navigation.md](docs/navigation.md) for
driving the desktop from the keyboard.

## Commands

```bash
omacos                       # grouped, self-documenting help
omacos commands --json       # machine-readable, for agents
omacos doctor                # what is actually true on this machine
omacos menu                  # everything, in one searchable menu

omacos window pin               # this window follows you to every workspace
omacos system info              # what this machine is, in one panel
omacos theme list|set|next|current|import
omacos theme background         # cycle the wallpapers a theme ships
omacos keymap show|build
omacos capture screenshot|screenrecording|text|color
omacos clipboard history|clear
omacos notice time|battery|weather
omacos reminder 7 'Tea ready'
omacos toggle idle|bar|gaps|dnd|nightlight|audio-output|menubar
omacos snapshot create|list|restore|delete   # Time Machine, without the disk
omacos font list
omacos feature enable desktop | apps
omacos setup signing            # git commit signing via 1Password
omacos git org add Acme         # per-org identity under ~/Work/Acme/

omacos app list [category]      # the catalog, and what you already have
omacos install app editor.zed   # a catalog id, or any Homebrew cask
omacos install launch service.spotify
omacos remove app               # asks which, and only removes what it installed
omacos default browser firefox  # installs it, then makes it the default
omacos default app music        # roles, recorded in local.env
omacos webapp install Linear https://linear.app
omacos tui install Docker lazydocker tile
omacos launch app music | omacos launch agent
omacos update
```

`omacos <group> <command> --help` documents one command; `omacos commands
--check` proves every one of them still documents itself.

Adding a command means adding a file to `bin/` with a `# omacos:summary=`
comment. There is no registry to update.

## What you get

**Terminal** — zsh (via `ZDOTDIR`, so `$HOME` stays clean), starship, fzf, atuin,
zoxide, eza, bat, ripgrep, fd, lazygit, delta, mise, direnv, Ghostty, Neovim,
tmux, btop.

**Desktop** (opt-in) — AeroSpace tiling, SketchyBar, JankyBorders, driven by a
keymap that generates both the window manager config and its own cheatsheet.
`alt-ctrl-k` shows them all. No dock, no desktop icons, and a wallpaper that is
no longer a button. Every item on the bar answers left, right and middle clicks
from one table you can edit. `alt-w` closes a window; `alt-q` quits the app,
because on macOS those are not the same thing.

Arrows and `hjkl` both move focus, and the pointer follows. `alt-s` drops into
a scratchpad workspace and back out. `alt-o` pins a window so it comes along to
every workspace you visit — AeroSpace has no sticky windows, so omacos carries
it on the workspace-change callback instead.

**Apps** are bound by *role*, not by name — the keymap says Music, and
`~/.config/omacos/local.env` says which one:

```bash
MUSIC_APP="Apple Music"     # alt-shift-m
NOTES_APP="Bear"            # alt-shift-o
```

A role with no app but a website opens the website, so `alt-shift-y` works
before you have installed anything.

**Apps** (opt-in) — a catalog of browsers, editors, terminals, AI apps, coding
agents, services, language runtimes, web apps and terminal apps, browsable from
`omacos menu` under Install and Remove. Rows for things you already have stay
listed but go dim and ticked, so the list reads as the state of the machine
rather than shrinking as you use it. A small bootstrap set in `Brewfile.apps`
installs on a new machine with one admin prompt for the whole batch rather than
one per `.pkg` cask, and sets Brave as the default browser — which also gives
`omacos webapp install` a real app window to work with.

The catalog is one file, `default/apps.json`, which the install menu, the
remove menu, the presence checks, `omacos default`, and the preinstall set all
read. Add to it in `~/.config/omacos/extensions/omacos-apps.jsonc`; reuse an id
and you replace only the fields you name.

```bash
omacos app list editor        # what is there, and what you have
omacos install app ai.ollama  # or any Homebrew cask by name
omacos default editor zed     # installs it if missing, then records it
```

**Web apps and terminal apps** — `omacos webapp install` builds a real `.app`
in `~/Applications` around a frameless browser window, icon and all, and
`omacos tui install` does the same for a terminal program. Both are removable
because omacos marks what it made; anything in `~/Applications` without that
marker is yours and is left alone. A web app can claim a URL scheme, so a
`mailto:` link can open HEY on a compose window.

**Themes** — one `colors.toml` per theme renders every app's colours, switches
macOS between light and dark, and sets the wallpaper. Ships 22 of them, most
ported from Omarchy with `omacos theme import`, which also takes any Omarchy
theme you point it at:

```bash
omacos theme import gruvbox            # an Omarchy theme, by name
omacos theme import ~/src/my-theme     # or a directory
```

Wallpapers are generated from the palette rather than copied — see
[themes/ATTRIBUTION.md](themes/ATTRIBUTION.md).

## The basics, on a Mac

Omarchy's everyday layer, done with what macOS already has rather than ported.

**Capture** — `alt-shift-p` takes a region, `alt-ctrl-p` starts and stops a
recording, `alt-ctrl-o` lifts text off the screen with OCR, and
`alt-ctrl-shift-c` is the system eyedropper. The last two have no CLI on macOS,
so omacos compiles a 40KB AppKit helper on demand rather than installing a
second OCR engine. Screenshots land where `screencapture` already puts yours.

**Clipboard history** — `alt-ctrl-v`. macOS already copies and pastes the same
way in the terminal and everywhere else, which is the problem Omarchy's Super+C
and Super+V exist to solve on Linux; history is the part macOS lacks. A login
agent records text you copy and skips anything a password manager marks
concealed. `omacos setup clipboard off` stops it, `omacos clipboard clear`
forgets it.

**Text extraction and dictation** — `alt-ctrl-o` selects a region and puts what
it says on the clipboard, through Vision rather than a downloaded OCR engine.
For dictation, macOS has its own — on-device, in any text field — so
`omacos setup dictation` turns that on and points at the shortcut instead of
shipping a second speech model.

**Notices and reminders** — the time, the battery or the weather as a
notification (`alt-ctrl-shift-t/b/w`), and `omacos reminder 7 'Tea ready'` on
`alt-ctrl-r`.

**Toggles** — hold off sleep (`alt-ctrl-i`), hide the top bar
(`alt-shift-space`), drop the window gaps (`alt-ctrl-g`), silence notifications
(`alt-ctrl-comma`), switch audio output, start the screensaver, flip Night
Shift. The status bar grows two indicators that draw nothing until they matter:
a recording light and a coffee cup.

Do Not Disturb and Night Shift both run through a Shortcut you make once —
macOS exposes neither to the command line, and Shortcuts' own *Set Focus* and
*Set Night Shift* actions are the only public-API route. `omacos setup dnd`
walks through it. Dismissing notifications is not offered: it is Notification
Center UI scripting that has broken in five macOS releases, so `alt-ctrl-shift-comma`
opens the settings pane instead.

**Snapshots** — Omarchy snapshots the system before it updates it, and macOS
has had the same thing built in for years with nobody using it: an APFS local
snapshot, copy-on-write, a second to take and no disk until the machine starts
diverging from it. `omacos update` now takes one before it changes anything,
which is what makes upgrading every package something you can walk back from.

```bash
omacos snapshot list              # the ones omacos took are marked
omacos snapshot restore --mount   # read-only, to get one file back
omacos snapshot restore           # the Recovery steps, for the whole disk
```

Rolling a whole volume back can only happen from macOS Recovery — it is the
volume you booted from — so that one prints the steps rather than pretending.
And a local snapshot is purgeable: a safety net for the next few hours, not a
backup.

Everything here is also under `alt-space`, in the menu.

### What macOS will not let this do

Omarchy binds a few things macOS keeps to itself. omacos does not ship a
private-API binary or a UI-scripting hack to fake them — each one is a real
limitation, not an oversight:

| Omarchy | Why not here |
|---|---|
| Dismiss / replay a notification | Only reachable by UI-scripting Notification Center, which has changed in five macOS releases and fails silently. `alt-ctrl-shift-comma` opens the settings instead. |
| Turn the built-in display off | No supported mechanism at all. |
| Toggle display mirroring | Only the Cmd-Brightness-Down keystroke macOS already provides. |
| Cycle monitor scaling | Needs `displayplacer`, which reports no display data on macOS 26, and a bad cycle can leave a screen unreadable. |
| Screen zoom | macOS has its own, off by default — `omacos setup zoom` turns that on rather than adding a second pair of chords. |

The window manager has limits of its own: AeroSpace is not Hyprland, so there
is no scrolling layout, no pseudo-tiling, no sticky window that follows you
between workspaces, and no mouse drag or resize of tiles. Stacking
(`alt-comma`) is as close as it gets to Omarchy's window groups — the same
"many windows, one slot", without a tab bar.

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
3. Turn off a class of defaults: `OMACOS_ALIASES=false`, `OMACOS_PROMPT=false`,
   `DESKTOP_ICONS=true`
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

Work in a checkout; keep `~/.local/share/omacos` as a plain clone of the remote
so you stay on the same update path as everyone else.

```bash
git clone git@github.com:ar4mirez/omacos.git ~/Work/ar4mirez/omacos
cd ~/Work/ar4mirez/omacos
./test/run.sh    # 157 tests, sandboxed — cannot touch your real home
./install.sh     # idempotent: a no-op on a configured machine

omacos dev link ~/Work/ar4mirez/omacos   # iterate without push-then-update
omacos dev status                        # which tree am I running?
omacos dev unlink
```

See [docs/architecture.md](docs/architecture.md#working-on-omacos-itself).

## Licence

MIT
