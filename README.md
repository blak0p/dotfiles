# Dotfiles — Host

Solo servicios + symlinks. Nada de dev tools, nada de AI en el host.
El tooling dev va adentro de un distrobox.

## Instalación

```bash
git clone git@github.com:blak0p/dotfiles.git ~/dotfiles
~/dotfiles/install.sh
```

Elegís los módulos que querés. Solo eso se instala.

### Módulos

| # | Módulo | Incluye |
|---|--------|---------|
| 1 | eden | Instala Eden (AppImage), PrismLauncher (flatpak), y crea symlinks al disco Juegos |
| 2 | gaming | Steam autopicture, ROM tools, auto-big-picture service |
| 3 | hardware | Deepcool AK620 + daemon |
| 4 | shell-core | cambiar_audio, cambiar_micro |

## Orden de instalación en una PC nueva

```
1. Montar disco Juegos
2. Gentleman Dots TUI → Ghostty, Fish, Tmux, Nvim (sin AI)
3. ~/dotfiles/install.sh → elegís "a" (todo)
4. Crear distrobox → tooling dev adentro
```

## Engram — backup de memorias

Antes de migrar de SO, exportar las memorias:

```bash
engram export ~/engram-backup.json
```

En la PC nueva, importarlas:

```bash
engram import ~/engram-backup.json
```

El export vive fuera del repo (no se sube a GitHub). Llevátelo en un USB o al disco Juegos.

## Estructura

```
dotfiles/
├── install.sh          # Instalador con checklist de módulos
├── INSTRUCCIONES.md    # Documentación detallada
├── scripts/            # Scripts sueltos (cambiar_audio, steam_*, convertir-nsz)
├── modules/
│   ├── eden/           # Symlinks al disco Juegos + instalación de emus
│   ├── gaming/         # Steam autopicture, ROM tools, systemd
│   ├── hardware/       # Deepcool AK620 + daemon
│   └── shell-core/     # cambiar_audio, cambiar_micro
└── Gentleman.Dots/     # Gentleman Dots (modificado, sin AI)
```
