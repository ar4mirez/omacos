# Navigation

Omarchy's manual has a chapter that teaches the desktop by driving it. This is
the same chapter for omacos, in the same order, so you can read them side by
side. Where macOS or AeroSpace will not do the thing Hyprland does, this says
so rather than pretending.

`alt` stands in for Omarchy's Super throughout. Cmd belongs to macOS apps — it
means something in every one of them — so a window manager that claimed Cmd
would spend its life fighting the system. If `alt` under your thumb is wrong,
`omacos setup capslock option` puts it under your left pinky instead.

Everything below needs the desktop layer:

```bash
omacos feature enable desktop
omacos install feature desktop
```

## Start with two windows

`alt-space` opens the omacos menu, and from there you can reach just about
everything. But the menu is not meant to be how you work. The things you do
constantly have keys of their own.

Press `alt-enter` for a terminal, then `alt-shift-enter` for a browser. The
terminal moves over to make room; nothing overlaps and nothing was dragged.

`alt-slash` turns the split, so the two sit one above the other instead of side
by side. Press it again to turn it back. `alt-shift-l` — or `alt-shift-right` —
swaps them.

Now `alt-ctrl-t` for the activity monitor and `alt-shift-f` for Finder, and you
have the same four-way tiling Omarchy's chapter ends up with.

## Moving around

| | |
|---|---|
| `alt-h/j/k/l` or `alt-arrows` | focus left, down, up, right |
| `alt-shift-h/j/k/l` or `alt-shift-arrows` | move the window that way |
| `alt-tab` | the window you were on before |
| `alt-backtick` | cycle through the windows here (`alt-cmd-backtick` backwards) |

The arrows and hjkl are the same four commands, bound twice on purpose: the
arrows are what you reach for on the first day and hjkl is what you settle into.
The keymap is yours, so delete whichever pair you stop using.

Focus moves the pointer with it, to the centre of the window you land on — the
same thing Omarchy's `Super + Arrow` does. It is a *lazy* centre: if the pointer
is already inside that window it stays put, so clicking never yanks the cursor
out from under you.

## Workspaces

| | |
|---|---|
| `alt-1`..`alt-6` | go there |
| `alt-shift-1`..`6` | send this window there, and follow it |
| `alt-shift-cmd-1`..`6` | send it there and stay where you are |
| `alt-leftSquareBracket` / `alt-rightSquareBracket` | previous, next |
| `alt-ctrl-tab` | the workspace you were on before |

There is no animation between them, because AeroSpace does not use native
Spaces at all — it moves windows off-screen and back. That is also why the top
bar has to be told about a workspace change explicitly, and why a workspace you
never visit still shows up: `persistent-workspaces` is generated from the
keymap, so the bar always shows the same set.

On more than one display, `alt-cmd-1`..`6` pulls a workspace onto the display
you are looking at instead of moving you to it.

## What the mouse does not do

Omarchy lets you hold Super and drag a window to rearrange it, or hold Super
and right-drag to resize it. AeroSpace has no modifier-drag, and macOS has no
way to add one without a third-party input driver, so omacos does not have this.

The keyboard equivalents are `alt-shift-<direction>` to move a tile,
`alt-equal` and `alt-minus` to resize, `alt-r` for a resize mode where hjkl
resize until you press escape, and `alt-cmd-equal` to give up and let AeroSpace
balance everything.

## Closing things

**`alt-w` closes a window. `alt-q` quits the app.** On Linux those are the same
key, because closing the last window ends the program. On macOS it does not:
the app stays running with no window, still holding the menu bar, and a tiling
window manager has nothing left to tile. So omacos splits them the way Cmd-W
and Cmd-Q already do everywhere else on this machine.

`alt-cmd-w` closes every window on this workspace, which is Omarchy's
Ctrl+Alt+Delete. It is deliberately not next to `alt-w`: closing one window is
a reflex, and closing all of them should take a second thought.

## Three kinds of full screen

| | |
|---|---|
| `alt-f` | fullscreen, keeping the outer gap — the bar still reads |
| `alt-ctrl-f` | edge to edge, over the bar |
| `alt-cmd-f` | hand the window to macOS, which gives it a Space of its own |

Omarchy's third one — full screen *inside* a window, for YouTube — is not a
window-manager job on a Mac. Every app that has it already binds it itself.

## Dwindle, and what omacos has instead

AeroSpace has no scrolling layout, so the per-workspace choice Omarchy makes
with `Super + L` has nothing to toggle between. What it has is a tiling tree
that behaves like dwindle: every window on a workspace stays visible, shrinking
to fit, and nested containers take the opposite orientation of their parent —
which is what makes a new window split the tile you are on rather than the
whole screen.

The two knobs that matter:

| | |
|---|---|
| `alt-slash` | turn this split — horizontal ↔ vertical |
| `alt-cmd-equal` | balance every window on this workspace |

If a workspace has got into a shape you cannot argue with, `alt-shift-semicolon`
then `r` flattens the whole tree and starts it over.

## Grouping windows

Omarchy's `Super + G` puts several windows in one slot. AeroSpace calls the same
idea an accordion, and omacos calls it a stack:

| | |
|---|---|
| `alt-comma` | stack the windows in this container, or unstack them |
| `alt-cmd-comma` | pull the window to the right into a stack with this one |
| `alt-h` / `alt-l`, `alt-backtick` | move between the stacked windows |
| `alt-shift-j` / `alt-shift-k` | lift this window back out of the stack |

There is no tab bar, and there is no "jump to the third one in the group" —
cycling is the only ordering there is. Everything else about the shape is the
same: many windows, one slot, and the rest of the workspace unaffected.

## Pinning a window everywhere

Omarchy's `Super + O` pops a window out of its workspace and pins it as a
floating overlay that follows you. AeroSpace has no sticky windows, so omacos
builds the behaviour out of two things it does have — a floating layout, and a
callback on every workspace change:

```
alt-o        pin this window, or unpin it
```

The pinned window floats above whatever you are doing and is carried to each
workspace you switch to. Good for a video, a timer, or a terminal running an
agent you want to keep half an eye on. It does not take focus when it arrives;
it just turns up.

One difference from the screenshot in Omarchy's manual: there, the popped
window is redrawn as a centred, inset panel. Here it keeps the size and
position it already had. AeroSpace declines to resize or move a floating
window at all — `resize` answers *"doesn't support floating windows yet"* and
points at [AeroSpace#9](https://github.com/nikitabobko/AeroSpace/issues/9) —
and the alternative, driving the window's frame through the Accessibility API,
means a second permission grant for whatever shell ran the key. Size it once
by hand and it stays that size.

A pin is a window id on disk, so it lasts exactly as long as the window does.
Closing the window drops the pin, and so does restarting AeroSpace — ids belong
to a single run and inheriting them would eventually pin something at random.

```bash
omacos window pin          # toggle the focused window
omacos window pin list     # what is pinned right now
omacos window pin clear    # unpin everything
```

## The scratchpad

There is a workspace called `S` that nothing else sends windows to, which makes
it the overlay workspace from Omarchy's chapter.

| | |
|---|---|
| `alt-s` | drop into the scratchpad, or back out of it |
| `alt-shift-s` | put this window on the scratchpad |

`alt-s` is a toggle in both directions: press it on the scratchpad and you land
back on the workspace you came from, which is what gives it the Quake-console
feel. `alt-shift-s` deliberately does *not* follow the window — sending
something out of sight is the whole point.

It is a full workspace rather than a panel that drops over the current one, so
a single window on it fills the screen instead of sitting centred — the same
missing ability as above, from the same place: nothing can position a floating
window. To take a
window off the scratchpad, send it somewhere directly with `alt-shift-1`.

## Where this stops

Three things from Omarchy's chapter have no honest equivalent here, and omacos
would rather say so than ship a hack that breaks every autumn:

- **The scrolling layout**, and `Super + L` to choose it per workspace.
  AeroSpace is not Hyprland; there is one tiling model and it is dwindle-shaped.
  When a workspace has more windows than it can usefully show, `alt-comma`
  stacking is the nearest thing: the windows keep a usable size and you move
  through them instead of squeezing them all on screen at once.
- **Super-drag and Super-right-drag.** No modifier-drag without an input driver.
- **Placing a floating window.** Nothing in AeroSpace can move or resize one
  ([AeroSpace#9](https://github.com/nikitabobko/AeroSpace/issues/9)), which is
  why a pinned window is not re-centred and why the scratchpad cannot drop down
  as a panel. Both would need the same thing, and it does not exist yet.

## The whole map

| Omarchy | omacos | |
|---|---|---|
| `Super + Space` | `alt-space` | the menu |
| `Super + Return` | `alt-enter` | terminal |
| `Super + Shift + Return` | `alt-shift-enter` | browser |
| `Super + J` | `alt-slash` | turn the split |
| `Super + Arrow` | `alt-arrows`, `alt-hjkl` | focus, pointer follows |
| `Super + Shift + Arrow` | `alt-shift-arrows` | move the tile |
| `Super + T` | `alt-t` | float this one |
| `Super + Ctrl + T` | `alt-ctrl-t` | activity monitor |
| `Super + Shift + F` | `alt-shift-f` | files |
| `Super + Shift + N` | `alt-shift-N` | send it there, follow |
| `Super + Shift + Alt + N` | `alt-shift-cmd-N` | send it there, stay |
| `Super + W`, `Super + Q` | `alt-w`, `alt-q` | window, then app — see above |
| `Ctrl + Alt + Delete` | `alt-cmd-w` | close everything here |
| `Super + F` | `alt-f` | fullscreen |
| `Super + Alt + F` | `alt-ctrl-f` | edge to edge |
| `Super + Ctrl + F` | — | the app's own key |
| `Super + L` | — | no scrolling layout |
| `Super + G` | `alt-comma` | stack, or unstack |
| `Super + Ctrl + Arrow` | `alt-h`/`alt-l` | move within the stack |
| `Super + Alt + G` | `alt-shift-j`/`k` | lift it out |
| `Super + O` | `alt-o` | pin it everywhere, at its own size |
| `Super + Grave`, `Super + S` | `alt-s` | the scratchpad, both ways |
| `Super + Shift + Grave`, `Super + Alt + S` | `alt-shift-s` | put it there |

## It takes some getting used to

It does. One key gets you through the first week:

```
alt-ctrl-k
```

Every binding, on screen, generated from the same `~/.config/omacos/keymap.conf`
that AeroSpace is generated from — so it cannot drift from what the keys
actually do. Change a line, run `omacos keymap build`, and both change together.
