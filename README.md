# dotfiles

Host config: servicios + symlinks. Dev tooling va dentro de Distrobox.

## Estructura

```
dotfiles/
├── config/             → symlinks a ~/.config/<app>/
│   ├── hypr/           Hyprland WM
│   ├── waybar/         Barra
│   ├── nvim/           Neovim (LazyVim)
│   ├── fish/           Shell
│   ├── ghostty/        Terminal
│   ├── caelestia/      Desktop theme/shell
│   ├── starship.toml   Prompt
│   ├── gtk-3.0/        GTK theme
│   ├── gtk-4.0/        GTK theme
│   ├── spicetify/      Spotify
│   ├── btop/           Monitor
│   ├── cava/           Audio visualizer
│   ├── alacritty/      Terminal (fallback)
│   ├── foot/           Terminal (fallback)
│   └── ...
├── scripts/            → symlinks a ~/scripts/
│   ├── cambiar_audio.sh
│   ├── cambiar_micro.sh
│   ├── steam_autopicture.sh
│   ├── steam_toggle.sh
│   └── convertir-nsz
├── host/
│   └── personal-pc/    Lo que cambia por máquina
│       ├── audio.sh    IDs/nombres de audio
│       ├── monitors.lua
│       ├── env.sh
│       └── packages.txt
├── modules/
│   ├── eden/           Emulador + symlinks al disco Juegos
│   ├── gaming/         Steam autopicture service
│   └── hardware/       Deepcool AK620 daemon
├── install.sh          Deploya symlinks + módulos
├── doctor.sh           Diagnóstico
└── assets/
```

## Instalación

PC nueva:
1. Instalar CachyOS + paquetes base (`host/personal-pc/packages.txt`)
2. Clonar: `git clone https://github.com/tuuser/dotfiles ~/dev/dotfiles`
3. `cd ~/dev/dotfiles && ./install.sh`
4. Gentleman Dots aparte con su TUI
5. Distrobox con herramientas dev

## Mantenimiento

```bash
./install.sh --all       # Deployar todo
./doctor.sh              # Ver qué falta/está roto
```

Las configs de `~/.config/` se manejan via symlinks: editar en el repo, se refleja automático.
