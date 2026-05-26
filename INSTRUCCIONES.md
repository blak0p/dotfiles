# 🛠️ Dotfiles — Instalación por Módulos

## En una PC nueva

```bash
git clone git@github.com:Alejandro-M-P/dotfiles.git ~/dotfiles
~/dotfiles/install.sh
```

El instalador te muestra una lista de módulos. Elegís los que quieras y solo eso se instala.

### Módulos disponibles

| # | Módulo | Incluye |
|---|--------|---------|
| 1 | shell-core | bashrc, bashrc.d base (aliases, fzf, zoxide, completions), zshrc, nanorc, gitconfig |
| 2 | prompt | oh-my-posh (tema), starship |
| 3 | apps | kitty, btop, fastfetch |
| 4 | gaming | Steam autopicture, ROM tools, auto-big-picture service |
| 5 | ai | Gentle AI, Ollama |
| 6 | dev | LazyGit, Axiom, scripts de desarrollo |
| 7 | hardware | Deepcool AK620 + daemon |

### Para tu PC (todo)

```bash
~/dotfiles/install.sh
# Elegí "a" (todos)
```

### Para la PC de tu novia (solo gaming)

```bash
~/dotfiles/install.sh
# Elegí: 1,2,3,4  (shell-core + prompt + apps + gaming)
```

## Cómo agregar un módulo nuevo

1. Creá `modules/<nombre>/install.sh`
2. Poné los scripts, configs, systemd, bashrc.d dentro del módulo
3. Agregalo a las listas `MODULE_NAMES` y `MODULE_DESCS` en `install.sh`
4. Agregá la función de chequeo en `doctor.sh`

Cada módulo es autónomo — incluye TODO lo que necesita (scripts + config + systemd + bashrc.d).

## Diagnóstico

```bash
~/dotfiles/doctor.sh
```
Detecta automáticamente qué módulos están instalados y verifica solo esos.
