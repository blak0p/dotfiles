# Dotfiles — Host

Solo servicios + symlinks. Nada de dev tools, nada de AI.

## En una PC nueva

```bash
git clone git@github.com:Alejandro-M-P/dotfiles.git ~/dotfiles
~/dotfiles/install.sh
```

### Módulos disponibles

| # | Módulo | Incluye |
|---|--------|---------|
| 1 | eden | Symlinks de Eden y PrismLauncher al disco Juegos |
| 2 | gaming | Steam autopicture, ROM tools, auto-big-picture service |
| 3 | hardware | Deepcool AK620 + daemon |
| 4 | shell-core | cambiar_audio, cambiar_micro |

### Para tu PC

```bash
~/dotfiles/install.sh
# Elegí "a" (todos)
```

### Para la PC de tu novia

```bash
~/dotfiles/install.sh
# Elegí: 2 (solo gaming)
```

## Gentleman Dots

Instalalo aparte con su TUI. Elegí lo que quieras (Ghostty, Fish, Tmux, Nvim).
Cuando te pregunte por AI tools (Claude Code, OpenCode) — decile que no.

## Distrobox

El tooling dev (git, gh, node, gentle-ai, engram, codegraph, etc.) va todo adentro de un distrobox.
No se instala nada de eso en el host.
