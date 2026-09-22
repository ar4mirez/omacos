# Coming from macOS

Omarchy's manual has a chapter for people arriving from a Mac. This is the
mirror of it: you are already on the Mac, and what is new is everything omacos
puts on top. The shape is deliberately the same, chapter for chapter, because
the questions turn out to be the same questions.

Everything below assumes the desktop layer:

```bash
omacos feature enable desktop
omacos install feature desktop
```

Without it you get the terminal half of omacos and none of the window
management, which is a perfectly good place to stop.

## alt is the center of everything

Omarchy hangs nearly every hotkey off Super. omacos hangs them off **alt**,
because Cmd belongs to macOS apps — Cmd-W, Cmd-Q, Cmd-T mean something in
every one of them, and a window manager that claimed Cmd would be fighting the
whole system. Nothing else claims `alt-1`..`alt-9`.

| | |
|---|---|
| `alt-space` | the omacos menu — launch, install, capture, settings |
| `alt-cmd-space` | apps only |
| `alt-enter` | terminal |
| `alt-shift-enter` | browser |
| `alt-ctrl-k` | **every binding, on screen** |

That last one is the only one worth memorising. It is also the first row of
`alt-space`, so forgetting it costs you one keystroke.

If `alt` under your thumb is wrong for you, move it under your left pinky:

```bash
omacos setup capslock option    # Caps Lock becomes a second alt
```

That is as close to Omarchy's Super as macOS gets without a kernel extension.
`hidutil` ships with the OS, so there is nothing to approve and nothing to
break on the next upgrade.

## There's no dock and no desktop icons

The Dock auto-hides with no delay, desktop icons are turned off, and clicking
the wallpaper no longer sweeps your windows aside to show it. `~/Desktop` is
still a folder and Finder still opens it — it has just stopped being a surface
that sits behind everything collecting files.

Plenty of people work off the desktop, though, so this one is an opinion you
can decline. In `~/.config/omacos/local.env`:

```bash
DESKTOP_ICONS=true
```

Icons come back, and stay back — an install that keeps re-hiding something you
put back is a fork waiting to happen.

What replaces them is the bar across the top: workspaces on the left, the
focused app beside them, and on the right the things that are true right now.
Two of its items draw nothing at all until they matter — a recording light and
a coffee cup for held-off sleep — which is the point. A bar that is always full
is a bar you stop reading.

**Every item takes clicks, and the three buttons do different things.** That
table lives in one file, `~/.config/sketchybar/plugins/click.sh`:

| item | left | right | middle |
|---|---|---|---|
| a workspace number | go there | send this window there | pull it to this monitor |
| front app | the apps menu | quit the app | the keybinding cheatsheet |
| clock | time as a notification | Date & Time settings | your calendar |
| battery | battery as a notification | Battery settings | hold off sleep |
| theme | next theme | pick a theme | next wallpaper |
| recording, coffee cup | stop it | stop it | stop it |

macOS keeps its own menu bar above all this. It is the only real duplication
left, and it is one command away if you want it gone:

```bash
omacos toggle menubar
```

Off by default, because a good many Mac apps keep the only copy of a command
up there.

## Windows place themselves

Open a second window and the first one moves over. Nothing overlaps, nothing
has to be dragged, and there is no animation between workspaces because
AeroSpace does not use native Spaces at all.

| | |
|---|---|
| `alt-h/j/k/l`, or the arrows | focus left, down, up, right |
| `alt-shift-h/j/k/l`, or the arrows | move the window that way |
| `alt-1`..`alt-6` | go to a workspace |
| `alt-shift-1`..`6` | send this window there, and follow it |
| `alt-shift-cmd-1`..`6` | send it there and stay where you are |
| `alt-t` | let this one float |
| `alt-o` | pin it, so it follows you to every workspace |
| `alt-f` | fullscreen |
| `alt-s` | the scratchpad, both ways — `alt-shift-s` sends something there |
| `alt-comma` | stack windows in one slot |

Focus takes the pointer with it, to the centre of the window you land on. The
full chapter — splitting, stacking, pinning, the scratchpad, and the three
things AeroSpace will not do — is [docs/navigation.md](navigation.md).

The keymap is a text file, `~/.config/omacos/keymap.conf`, and it is the source
of truth: `aerospace.toml` is generated from it and carries a do-not-edit
header. Change a line, run `omacos keymap build`, and the cheatsheet changes
with it.

## Copy and paste already work

This is the chapter Omarchy needs and macOS does not. Cmd-C and Cmd-V already
mean the same thing in the terminal as everywhere else, so omacos leaves them
alone and adds only the part macOS is missing:

```
alt-ctrl-v      clipboard history
```

A login agent records what you copy, and **skips anything a password manager
marks concealed**. That rule is the difference between a clipboard history and
a password log. `omacos setup clipboard off` stops it; `omacos clipboard clear`
forgets it.

## The translation table

| Instead of | Press, or run |
|---|---|
| Spotlight, Raycast | `alt-space` |
| Mission Control | `alt-1`..`alt-6` — the workspaces are already separate |
| Cmd-Tab | `alt-tab` for the last window, `alt-backtick` to cycle this one |
| Dragging windows | `alt-shift-h/j/k/l`, or the arrows |
| Cmd-Shift-4 | `alt-shift-p` (and Cmd-Shift-4 still works) |
| Screen recording | `alt-ctrl-p` starts and stops |
| Digital Color Meter | `alt-ctrl-shift-c` |
| Live Text, by hand | `alt-ctrl-o` lifts text off any region |
| **Time Machine** | **`omacos snapshot`** — see below |
| App Store | `alt-space` › Install, or `omacos install app <id>` |
| System Settings | `alt-space` › Setup |
| Notification Center | `alt-ctrl-shift-comma` opens the settings; see the caveat below |
| AirDrop | AirDrop. It is already here, and it already works |

## Snapshots, which is Time Machine without the disk

Omarchy snapshots the system before it updates it. macOS has had the same
thing built in for years, switched off in everybody's head: an **APFS local
snapshot**. It is copy-on-write, so taking one costs a second and no disk
space, and it grows only as the machine diverges from it. `tmutil` will make
one whether or not you have ever configured Time Machine.

```bash
omacos snapshot create      # takes about a second
omacos snapshot list        # the ones omacos took are marked
omacos snapshot restore     # what to do, both kinds
omacos snapshot delete
```

**`omacos update` takes one before it changes anything**, which is what makes
upgrading every package on the machine something you can walk back from. There
is no flag to skip it: the update you would reach for that flag on is the one
you most want to be able to undo. If a snapshot genuinely cannot be taken —
not APFS, no space — the step says so and the update carries on.

Two different jobs wear the word *restore*, and only one can be scripted:

- **Getting one file back.** `omacos snapshot restore --mount` mounts the
  snapshot read-only and tells you where your home directory was. Copy what
  you need out and unmount it. This is the answer nine times out of ten.
- **Rolling the whole disk back.** Only macOS Recovery can do this, because
  the volume being replaced is the one you booted from. `omacos snapshot
  restore` prints the steps; local snapshots appear in Recovery's "Restore
  From Time Machine" even with no Time Machine disk ever configured.

macOS treats local snapshots as purgeable and thins them as the disk fills, so
this is a safety net for the next few hours, not an archive. It is not a
backup. Keep the real one.

## Some things really are different

**`alt-w` closes a window. `alt-q` quits the app.** On Linux those are the same
key because closing the last window ends the program. On macOS it does not:
the app stays running with no window, still holding the menu bar, and a tiling
window manager has nothing left to tile. So omacos splits them the way Cmd-W
and Cmd-Q already do everywhere else on this machine.

**Software comes from a package manager.** `omacos install app editor.zed`, or
any Homebrew cask by name, or `alt-space` › Install. No downloaded disk images
to drag anywhere.

**Config is text, and it is yours.** Everything omacos seeds into `~/.config`
is written once and then never touched again, so it is safe to point your own
dotfiles repo at it. Updates improve the defaults underneath without rewriting
your choices. `omacos refresh config <path>` takes a newer default deliberately,
with a diff and a backup.

**One update command.** `omacos update` snapshots, pulls omacos, runs
migrations, seeds anything new, upgrades your packages and reapplies your
theme.

## What is bound to a role, not an app

The keymap says *Music*; `~/.config/omacos/local.env` says which one:

```bash
MUSIC_APP="Apple Music"     # alt-shift-m
NOTES_APP="Bear"            # alt-shift-o
```

A role with no app but a website opens the website, so `alt-shift-y` reaches
YouTube before you have installed anything at all.

## Where omacos stops

Some of Omarchy's chapter has no honest equivalent here, and omacos would
rather say so than ship a UI-scripting hack that breaks every autumn.

- **Dismissing or replaying a notification.** Only reachable by scripting
  Notification Center's UI, which has changed in five macOS releases and fails
  silently. `alt-ctrl-shift-comma` opens the settings pane instead.
- **Turning the built-in display off, mirroring, cycling scaling.** No
  supported mechanism, or one that can leave a screen unreadable.
- **Scrolling layouts, pseudo-tiling, dragging a tile with the mouse.**
  AeroSpace is not Hyprland: there is one tiling model, and no modifier-drag.
  `alt-comma` stacking is the closest thing to Omarchy's window groups, and
  `alt-o` is Omarchy's `Super + O` rebuilt out of a floating layout and a
  workspace-change callback, since AeroSpace has no sticky windows of its own.
- **A true hyper key.** Not expressible in `hidutil`; it needs
  Karabiner-Elements and a DriverKit extension. `omacos setup capslock hyper`
  explains the trade rather than installing one behind your back.

Three things cannot be scripted at all and omacos will only ever tell you
about them: granting AeroSpace Accessibility, and 1Password's *Use the SSH
agent* and *Integrate with 1Password CLI* toggles. `omacos doctor` names them
whenever they are missing.

## Give it two weeks

The first day is slow. You will reach for the trackpad, hit Cmd where alt was
meant, and lose a window into a workspace you did not mean to leave.

One hotkey gets you through it:

```
alt-ctrl-k
```

Everything else is discoverable from `alt-space`, and `omacos doctor` will
tell you what on this machine is not yet true.
