# Parity with Omarchy's manual

Omarchy's manual is 51 chapters. This is a chapter-by-chapter account of where
omacos stands against each one, so that "how close is this to Omarchy?" has an
answer you can check rather than a feeling.

It is deliberately unflattering. A feature that is missing is listed as missing,
and a feature that omacos does differently says why — because the alternative,
quietly scoring a chapter as done because something vaguely similar exists, is
how a port ends up claiming things it cannot do.

| | |
|---|---|
| **done** | the chapter's feature is here |
| **differs** | here, but deliberately not the same — the note says why |
| **n/a** | nothing to port; it is Linux, firmware, or Omarchy's own software |
| **open** | a real gap, and a fair thing to ask for |

## The desktop

| # | Chapter | | Notes |
|---|---|---|---|
| 01 | Welcome | n/a | Prose. |
| 02 | Getting started | differs | An ISO and a partitioning wizard become `curl \| bash`. No disk to encrypt: FileVault is macOS's, and already there. |
| 03 | Coming from Mac/Windows | done | Answered chapter-for-chapter in [coming-from-macos.md](coming-from-macos.md). |
| 04 | Navigation | done | Answered chapter-for-chapter in [navigation.md](navigation.md), and every binding in it driven on a live desktop. Three things stay out of reach and say so there. |
| 05 | The top bar | differs | SketchyBar, with every item answering left, right and middle click from one editable table. Omarchy's *panels* are in-bar popups; omacos opens the matching System Settings pane instead, because macOS already owns that UI. **Open:** indicators for Do Not Disturb, Night Shift and pending reminders; an update-available badge; `bar position` / `transparent` commands. |
| 06 | Themes | done | 22 themes, the same count. `alt-ctrl-shift-space` picks one, `alt-ctrl-space` cycles its backgrounds. Unlock screens are n/a — the FileVault screen is not themeable. |
| 07 | Hotkeys | done | 136 bindings, `alt-ctrl-k` shows them all. **Open** from this chapter: an emoji picker key (macOS's own needs Accessibility to trigger from a script), window transparency, save/restore window width. |

## Everyday tools

| # | Chapter | | Notes |
|---|---|---|---|
| 08 | Unified clipboard | differs | The chapter exists to fix a Linux problem — `Ctrl+Shift+C` in the terminal, `Ctrl+C` everywhere else. macOS has never had it. omacos adds only the part macOS lacks: history on `alt-ctrl-v`, with anything a password manager marks concealed skipped. Text only; Omarchy's also holds images. |
| 09 | Reminders | done | `alt-ctrl-r` set, `alt-ctrl-cmd-r` list, `alt-ctrl-shift-r` clear, plus `omacos reminder`. |
| 10 | Notices | done | Time, battery and weather on `alt-ctrl-shift-t/b/w`. `omacos notice location` pins the weather when IP geolocation guesses wrong. |
| 11 | Text extraction & dictation | differs | OCR on `alt-ctrl-o` via the native Vision framework — no second OCR engine. Dictation is macOS's own, on-device; `omacos setup dictation` turns it on, but its shortcut lives behind a settings pane no script can drive, so there is no toggle key. |
| 12 | Screenshots & recording | differs | Screenshot, region, window, recording, colour picker — all there, saving wherever macOS is already configured to save. macOS's own capture gives you the annotation editor. **Open:** QR decode, and transcoding media before sharing. The webcam overlay is n/a. |
| 13 | Toggles, idle, screensaver | done | Night Shift, Do Not Disturb, stay awake, gaps, bar, screensaver, lock. Flags live in state, and `omacos state check` is the script predicate. Dismissing and replaying notifications is not scriptable on macOS and says so. |
| 14 | Omarchy CLI | done | Same shape throughout: groups, `--help` at every level, `commands --json`, `commands --check`. Adding a command is adding a file. |

## Software

| # | Chapter | | Notes |
|---|---|---|---|
| 15–18 | Terminal, Neovim, AI, dev tools | done | Ghostty, LazyVim, and a 68-entry catalog covering browsers, editors, terminals, AI apps, coding agents, services and runtimes. |
| 19 | Shell tools | differs | fzf, zoxide, ripgrep, eza, bat, fd, atuin, direnv, mise all ship. **Open:** `tldr`, `yt-dlp`, `try`. |
| 20 | Shell functions | open | **The largest single gap.** None of Omarchy's shell functions exist here: `compress`/`decompress`, the tmux dev layouts (`tdl`, `tds`, `tsl`), the git worktree helpers (`ga`, `gd`), the rsync watchers (`rsw`, `lsw`, `dsw`), the SSH port-forward helpers (`fip`, `dip`, `lip`), the reconnecting `ssh` wrapper, and `ff`. Almost all of it is portable as-is. |
| 21–25 | TUIs, GUIs, browsers, commercial apps, web apps | done | `omacos tui install`, `omacos webapp install`, `omacos default browser`, and the catalog behind all of them. |
| 26–29 | Gaming, PDFs, Windows VM, other packages | n/a | Steam aside, this is Proton, Lutris and virt-manager. Preview fills in PDFs; Homebrew is the package manager. |

## The system

| # | Chapter | | Notes |
|---|---|---|---|
| 30 | Updates | differs | `omacos update` snapshots, pulls, migrates, seeds, upgrades and re-themes. Omarchy's four release channels become one: `omacos dev link` is the dev channel. **Open:** the update-available badge in the bar. |
| 31 | Dotfiles | done | The ownership boundary is omacos's central idea — see [architecture.md](architecture.md). Hooks fire on `post-install`, `post-update` and `theme-set`, with samples shipped for each. **Open:** `font-set` and `battery-low` hook events. |
| 32 | Shell plugins | differs | zsh, not bash. The extension point is `~/.config/zsh/local.zsh`. |
| 33 | Monitors | n/a | Scaling, mirroring, arrangement and brightness are macOS's, and it is better at them. **Open:** a single text-size knob across terminal and bar. |
| 34 | Keyboard, mouse, trackpad | n/a | System Settings. `omacos setup capslock` is the one thing worth scripting. |
| 35 | Networking | n/a | macOS owns Wi-Fi and Ethernet. **Open, and all easy:** `networkQuality` is a built-in speed test, `networksetup` sets DNS, and sharing Wi-Fi by QR code is a real convenience. |
| 36 | System sleep | differs | Suspend and hibernation are macOS's business. **Open:** Low Power Mode as a toggle, which is the closest thing to power profiles. |
| 37 | Hardware authentication | open | Omarchy does fingerprint auth for the lock screen and `sudo`. macOS has Touch ID for both, and `sudo` needs one line in `/etc/pam.d/sudo_local`. This is the clearest unclaimed win in the manual. |
| 38 | Fonts | differs | `omacos font list` reports what is installed. **Open:** choosing one, and installing more — Omarchy has *Style > Font* and *Install > Style > Font*. |
| 39 | Backgrounds | done | Per-theme, plus anything you drop in `~/.config/omacos/backgrounds/<theme>/`. Video wallpapers are n/a. |
| 40 | Prompt | differs | Starship ships and is initialised. **Open:** no `starship.toml` is seeded, so you get Starship's default rather than a curated one. |
| 41 | Branding | n/a | ASCII-art screensaver logos, for a screensaver macOS supplies. |
| 42 | Common tweaks | done | Gaps, the bar, and the menu bar are all one command. |
| 43 | Making your own theme | done | `omacos theme import`, and a converter that ported Omarchy's palettes rather than copying them by hand. Themes from strangers are stripped of anything executable. |

## The rest

| # | Chapter | | Notes |
|---|---|---|---|
| 44 | Mac support | n/a | This chapter is about running Omarchy *on* Mac hardware. omacos is the other direction. |
| 45 | Troubleshooting | differs | `omacos doctor` reports what is actually true, and names the three things no script can do. **Open:** a debug bundle to paste into an issue, and one-command restarts for Wi-Fi, Bluetooth and audio. |
| 46 | FAQ | differs | Spread across the docs rather than collected. |
| 47 | System snapshots | done | APFS local snapshots, taken before every update, restorable through Recovery. No bootloader required, because macOS has had this the whole time. |
| 48 | Security | differs | FileVault, Gatekeeper and the application firewall are macOS's and are on. 1Password's SSH agent holds the keys and nothing is written to `~/.ssh`. |
| 49–51 | Omarchy on, dual boot, unattended installs | n/a | ISO and firmware territory. |

## What is actually open

Ranked by what you would notice:

1. **Shell functions** (ch 20) — the whole layer is missing and nearly all of it ports unchanged.
2. **Touch ID for `sudo`** (ch 37) — one line of PAM config for the manual's whole hardware-auth chapter.
3. **Bar indicators** for Do Not Disturb, Night Shift and pending reminders (ch 05, 13) — the state is already tracked; nothing draws it.
4. **Fonts** (ch 38) — choosing and installing one. Ghostty already loads a generated include, so there is a clean place to put it.
5. **Networking odds and ends** (ch 35) — speed test, DNS, Wi-Fi QR. All native, all small.
6. **QR decode** (ch 12) — the Vision framework already does OCR for `omacos capture text`; barcodes are the same API.
7. **Transcode** (ch 12) — `sips` and ffmpeg.
8. **Update-available badge** (ch 05, 30).
9. **Low Power Mode** (ch 36), **a seeded `starship.toml`** (ch 40), **a debug bundle** (ch 45).
