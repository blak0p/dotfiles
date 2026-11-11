# User layer templates

`install.sh` copies these files to `$XDG_CONFIG_HOME/sky/hypr/` (default
`~/.config/sky/hypr/`) when they are missing; it never overwrites them.
That folder is yours: it is not part of the repo, so `git pull` never
conflicts with it, and the sky settings window (Super+I) saves there.

Every file is optional and loads after the repo defaults, so it wins:

| File | Use it for | Written by Settings |
|---|---|---|
| `env.lua` | environment variables (`hl.env`) | no |
| `variables.lua` | app variables such as `terminal`, `fileManager` | no |
| `execs.lua` | apps started with the session | no |
| `general.lua` | options, animations, gaps (`hl.config`) | no |
| `rules.lua` | window and layer rules | no |
| `keybinds.lua` | your own shortcuts (`hl.bind`) | Shortcuts page |
| `monitors.lua` | resolution, refresh rate, scale, position (`hl.monitor`) | Displays page |
| `workspaces.lua` | workspace-to-monitor rules | no |

A file with an error is reported in the Hyprland log and skipped; the rest of
the session still loads.
