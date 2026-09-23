# Shell functions

Omarchy ships a set of shell functions that wrap the long invocations you would
otherwise look up every time. This is that layer, ported to zsh and to macOS's
tools. It lives in `default/zsh/functions.zsh`, which is package-owned — add
your own in `~/.config/zsh/local.zsh`, which is sourced afterwards and wins.

Turn the whole thing off with `OMACOS_FUNCTIONS=false` in `local.zsh`.

## Compression

```bash
compress ~/Projects/report      # → report.tar.gz
decompress report.tar.gz
```

Two things worth knowing, both macOS-only. `COPYFILE_DISABLE=1` is set for you,
or `tar` writes an AppleDouble `._name` beside every entry and the archive
arrives full of junk on anyone else's machine. And macOS *has* a
`/usr/bin/compress` — the LZW one that makes `.Z` files — which this function
shadows. Only in your interactive shell: shell functions are not inherited by
scripts, so anything that runs `compress` non-interactively still gets the
binary. If you want it back at the prompt too, `command compress`.

## Finding files

```bash
ff          # fuzzy-find, with the file previewed and syntax-highlighted
eff         # the same, then open what you picked in $EDITOR
```

## Git worktrees

```bash
ga feature-x     # a worktree beside the repo, on a new branch, and cd into it
gd               # from inside one: remove the worktree and the branch
```

`ga` names the directory `<repo>--<branch>`, which is the whole trick: `gd`
works out what to remove from the directory name, so it needs no arguments.
It refuses to run anywhere that does not have that shape, so running it in an
ordinary checkout cannot delete your checkout. `mise trust` is run on the new
worktree, since mise trusts a config per directory.

## tmux dev layouts

All four need to be run from inside tmux, and all four take the coding agent you
already chose with `omacos default agent` — so usually you type no arguments.

```bash
tdl              # editor across the top, terminal along the bottom, agent right
tdl claude cx    # two agents, stacked down the right
tds              # a 2×2 square: editor, git diff, terminal, agent
tdlm             # one tdl window per subdirectory here
tsl 6 claude     # six tiled panes all running the same thing
```

Panes are targeted by id rather than by position. `tmux split-window -t` with no
pane id splits whichever pane is *active*, which after the first split is no
longer the one you meant — that is the bug that makes hand-rolled layouts come
out wrong on the second run.

## Rsync watchers

```bash
rsw ~/Work/app nyc-dev:Work/app   # mirror now, then on every change
lsw                               # what is being watched
dsw                               # stop watching
```

Omarchy uses `inotifywait`; this uses **fswatch**, which is the same idea and is
the one thing in this layer that has to be installed (`omacos update` does it).
One SSH connection is reused for the whole session, so 1Password asks once
rather than on every save.

`dsw` kills the watcher's children before the watcher itself — macOS has no
`setsid`, so the process group is shared, and stopping only the wrapper would
leave `fswatch` running and holding the pipe open.

## SSH port forwarding

```bash
fip nyc-dev 3000 5173    # localhost:3000 now reaches nyc-dev:3000
lip                      # what is forwarded
dip 3000                 # stop one
```

This is what a browser needs before it will treat a remote dev server as a
secure context, which is what websockets and a dozen other APIs require.

## ssh, wrapped

`ssh` is a function that does two things around the real one.

It **disarms the terminal** afterwards. A remote tmux or editor turns on mouse
tracking, focus reporting and the alternate screen over the SSH pipe, and only
it can turn them off again. If the link dies instead of exiting cleanly, those
stay armed locally and every mouse movement floods your prompt with escape
junk.

It **reconnects** when an established interactive session drops — and only
then. A remote command is never replayed, because re-running it would repeat
its side effects; a failure in the first 30 seconds is treated as a connect or
auth problem rather than a dropped session; and a `RemoteCommand` coming from
`ssh_config` is detected with `ssh -G` and counts as a command too. Ctrl-C stops
the retry loop.

## Drives

```bash
format-drive /dev/disk4 'My Stuff'   # one exFAT partition, readable everywhere
iso2sd ~/Downloads/thing.iso /dev/disk4
```

Both **refuse anything macOS does not report as an external disk**, and both
refuse a partition where a whole disk was meant. Run either with no arguments
to see the external disks you actually have. `iso2sd` writes to `/dev/rdiskN`
rather than `/dev/diskN` — the raw device is unbuffered and many times faster
for a linear write.

Omarchy does this with `parted` and `mkfs.exfat`; here it is `diskutil`, which
does the partition table, the filesystem and the remount in one step and
refuses on its own if the disk is busy.
