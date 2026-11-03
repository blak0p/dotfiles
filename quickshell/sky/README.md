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
| `island/CenterView.qml` | Control center: tiles, media, volume, pages (notifs, wifi, bluetooth, power, usage) |
| `UsageService.qml` / `scripts/fetch_usage.py` / `island/UsageCard.qml` | AI plan usage (Claude, Codex, Antigravity) from the [CodexBar](https://github.com/steipete/CodexBar) CLI `codexbar`; providers and refresh intervals in `Config.qml` (`usageProviders`, `usageIdleMs`, `usageOpenMs`) |
| `island/TrayPanel.qml` | System tray panel opened by the status pill chevron: one cell per StatusNotifierItem |
| `island/TrayIcon.qml` | One tray item: theme-icon resolution, click / middle-click / menu |
| `Theme.qml` | Palette from `~/.local/state/sky/colors.json`; regenerates it when the wallpaper changes |
| `wallpaper/WallpaperView.qml` / `WallpaperService.qml` | Wallpaper picker: horizontal picture strip grown out of the clock pill (no chrome); the list, thumbnails and apply live in `scripts/sky_wallpaper.py` |
| `Config.qml` / `island/IslandState.qml` | Sizes / island mode (idle, launcher, notif, volume, center) |

## IPC

- `qs -c sky ipc call launcher toggle|open|close`
- `qs -c sky ipc call island toggle|open|close|clear|dnd|tray|state`
- `qs -c sky ipc call island page notifs|wifi|bluetooth|power|usage` (toggles that page of the center)

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
