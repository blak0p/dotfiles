# sky: Quickshell config

Continuous-frame desktop shell for Hyprland (design: `design/new-shell/04-continuous-frame.html`).
Run with `qs -c sky`.

## Layout

| Path | Purpose |
|---|---|
| `shell.qml` | Entry: per screen a `Reserve` + an `Island`; IPC handlers (`launcher`, `island`) |
| `Reserve.qml` | Invisible click-through window that reserves the top bar space |
| `island/Island.qml` | Top overlay window: `[workspaces] [Dynamic Island] [status]` pills; the island morphs for notifications, volume, center and the launcher |
| `launcher/Launcher.qml` / `launcher/calc.js` | Launcher dropdown (an island view, not a window): app/command search plus an inline arithmetic calculator |
| `island/Notifs.qml` | Notification daemon (`org.freedesktop.Notifications`): popup queue, history, DND |
| `island/IslandState.qml` | Island mode (idle / notif / volume / center), center page, volume + OSD |
| `island/Net.qml` | Wi-Fi (NetworkManager) and Bluetooth (BlueZ) state and actions |
| `island/CenterView.qml` | Control center: module tabs (Quick settings, Performance, Music) plus single pages (wifi, bluetooth, sound, power, usage) |
| `PerfService.qml` / `scripts/sys_stats.py` / `island/PerfPage.qml` / `island/Spark.qml` | Performance tab: CPU (usage, temp, GHz), RAM, AMD GPU (usage, VRAM, temp, watts) and disks (space, read/write); the sampler runs only while the tab is open (tests: `python3 -m unittest discover -s tests`) |
| `island/Media.qml` / `island/MusicPage.qml` | Music tab (MPRIS): cover, seekable progress, shuffle/repeat, player volume and a chip per player; the idle island shows cover + title while playing, and clicking them opens this tab |
| `UsageService.qml` / `scripts/fetch_usage.py` / `island/UsageCard.qml` | AI plan usage (Claude, Codex, Antigravity) from the [CodexBar](https://github.com/steipete/CodexBar) CLI `codexbar`; providers and refresh intervals in `Config.qml` (`usageProviders`, `usageIdleMs`, `usageOpenMs`) |
| `island/TrayPanel.qml` | System tray panel opened by the status pill chevron: one cell per StatusNotifierItem |
| `island/TrayIcon.qml` | One tray item: theme-icon resolution, click / middle-click / menu |
| `Theme.qml` / `scripts/sky_theme.py` | Palette from `~/.local/state/sky/colors.json`; when the wallpaper changes it reruns `sky_theme.py`, which also recolors Hyprland borders, hyprlock, Kitty, GTK, btop and the Neovim `sky` colorscheme (tests: `python3 -m unittest discover -s tests`) |
| `wallpaper/WallpaperView.qml` / `WallpaperService.qml` | Wallpaper picker: horizontal picture strip grown out of the clock pill (no chrome), opened with `Ctrl+Super+T`, moved with arrows or `h`/`l`, `Enter` applies; the list, thumbnails and apply live in `scripts/sky_wallpaper.py` |
| `I18n.qml` / `i18n.js` | UI language: English plus Spanish (Spain). `Config.language` is `"auto"` (follows `LANG`), `"en"` or `"es"`; wrap new UI text in `I18n.t("…")` and add its translation to `i18n.js` (tests: `node --test tests/i18n.test.mjs`) |
| `Config.qml` / `island/IslandState.qml` | Sizes / island mode (idle, launcher, notif, volume, center) |

## IPC

- `qs -c sky ipc call launcher toggle|open|close`
- `qs -c sky ipc call island toggle|open|close|clear|dnd|tray|state`
- `qs -c sky ipc call island page notifs|perf|music|wifi|bluetooth|sound|power|usage` (toggles that page of the center)

## Notes

- No dock: the launcher is a compact dropdown that grows out of the island pill. It is **keyboard-only** (`Super+Space`, or `qs -c sky ipc call launcher toggle`); clicking the island still opens the control center (wifi, bluetooth, volume, notifications).
- The launcher doubles as a calculator: typing `2+2`, `sqrt(16)`, `200*15%` or `1,5*2` puts the result in the first row, and Enter copies it to the clipboard. `launcher/calc.js` is a small parser (no `eval`); its tests run with `node --test tests/calc.test.mjs`.
- AI usage needs `codexbar` on `PATH` (or `/home/linuxbrew/.linuxbrew/bin`); without it the status-pill button stays hidden and the page says so. A provider whose login expired keeps its card with "Session expired, sign in again" instead of disappearing. Tests: `python3 -m unittest discover -s tests`.

- Workspace switching uses the Hyprland 0.57 Lua dispatcher (`hl.dsp.focus({ workspace = N })`); the old `workspace N` syntax fails.
- Inline components with grouped properties (`border.width`) fail to load here ("X is not a type"); put such components in their own file.
- Fullscreen window on the shell monitor: pills hidden, normal notifications show as a small top-right toast (island/MiniToast.qml) and stay unread in the history; critical + volume still use the island.
- Tray apps started before the shell (re)started do not re-register; relaunch them to get their icon.
- The tray lives behind one chevron in the status pill, not inline: app icons come from their own icon themes and would be indistinguishable from the system icons beside them, and the pill would reflow on every app quit. The chevron (and its divider) only appears while at least one item is registered.
- `SystemTrayItem.icon` is a theme icon *name*, not a URL; it goes through `Quickshell.iconPath()` before reaching `IconImage`.
- `//@ pragma UseQApplication` in `shell.qml` is required for `QsMenuAnchor` (tray context menus). Without it every right-click logs "Cannot call QsMenuAnchor.open() as quickshell was not started in QApplication mode".
- The tray panel closes on: chevron toggle, item activation, opening the center, the volume OSD, or fullscreen. Clicking outside does not close it yet.
