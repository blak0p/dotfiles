# 🐚 dotfiles-shell

<p align="center">
  <img src="assets/shell-banner.png" alt="Shell Banner" width="100%" onerror="this.style.display='none'"/>
</p>

<p align="center">
  <a href="https://fishshell.com"><img src="https://img.shields.io/badge/Fish-Shell-green?style=for-the-badge&logo=gnubash&logoColor=white" alt="Fish Shell"/></a>
  <a href="https://starship.rs"><img src="https://img.shields.io/badge/Starship-Prompt-DD0B78?style=for-the-badge&logo=starship&logoColor=white" alt="Starship"/></a>
  <a href="https://sw.kovidgoyal.net/kitty"><img src="https://img.shields.io/badge/Kitty-Terminal-teal?style=for-the-badge&logo=kitty&logoColor=white" alt="Kitty"/></a>
  <a href="https://atuin.sh"><img src="https://img.shields.io/badge/Atuin-History-8134AF?style=for-the-badge" alt="Atuin"/></a>
  <a href="https://carapace.sh"><img src="https://img.shields.io/badge/Carapace-Completions-blue?style=for-the-badge" alt="Carapace"/></a>
</p>

<p align="center">
  A high-performance, ergonomic, and modular CLI stack built on <b>Fish Shell</b>, <b>Starship 2-Line Prompt</b>, <b>Atuin</b> encrypted SQLite history, <b>Carapace</b> lazy multi-shell completions (2,380+ tools), and <b>Kitty Terminal</b> with Ghostty-style shader cursor trails.
</p>

Part of the [dotfiles umbrella](https://github.com/blak0p/dotfiles).

---

## 🎬 Terminal Showcase

> [!TIP]
> Recorded showcase clips and demos are stored in `assets/shell-demo.mp4` and `assets/shell-demo.gif`.

<p align="center">
  <img src="assets/shell-demo.gif" alt="Shell Preview Demo" width="90%" onerror="this.style.display='none'"/>
</p>

---

## 📋 Table of Contents

- [What Gets Deployed](#what-gets-deployed)
- [Architecture & Dual-Layer Design](#architecture--dual-layer-design)
- [Fish Shell & Plugin Stack](#fish-shell--plugin-stack)
- [Starship Prompt & Visual Theming](#starship-prompt--visual-theming)
- [Kitty Terminal & Shader Effects](#kitty-terminal--shader-effects)
- [CLI Tools, Aliases & Functions](#cli-tools-aliases--functions)
- [Keybindings Matrix](#keybindings-matrix)
- [Installation & Setup](#installation--setup)
- [Private Configuration (`fish.custom`)](#private-configuration-fishcustom)

---

## 📦 What Gets Deployed

The installer creates symlinks from `~/.config/<name>` to this repository:

| Symlink                   | Configures      | Description                                                             |
| ------------------------- | --------------- | ----------------------------------------------------------------------- |
| `~/.config/fish`          | Fish Shell      | Core `config.fish`, custom functions, completions, and environment      |
| `~/.config/starship.toml` | Starship Prompt | 2-line prompt with git status, execution time, and directory truncation |
| `~/.config/atuin`         | Atuin History   | Encrypted SQLite history database with fuzzy interactive search         |
| `~/.config/carapace`      | Carapace        | Lazy-bridged completions for 2,380+ command-line tools                  |
| `~/.config/fastfetch`     | Fastfetch       | Structured hardware and OS diagnostics with Unicode borders             |
| `~/.config/kitty`         | Kitty Terminal  | Hardware-accelerated terminal with GPU shader cursor trail & blur       |
| `~/.config/herdr`         | Herdr           | Terminal and AI agent multiplexer (`Ctrl + A` prefix)                   |

---

## 🏗️ Architecture & Cross-Platform Design

The shell stack is engineered for portability, high performance, and ergonomics:

1. **Multi-OS PATH Assembly**:
   - **Linux**: Automatically integrates Homebrew (`/home/linuxbrew/.linuxbrew/bin`), Cargo (`~/.cargo/bin`), Volta (`~/.volta/bin`), Bun (`~/.bun/bin`), PNPM, and Nix profiles.
   - **macOS (Darwin)**: Auto-detects Apple Silicon (`/opt/homebrew`) vs Intel (`/usr/local/bin`).
   - **Termux / Android**: Detects `$TERMUX_VERSION` and configures `$PREFIX/bin`.
2. **Hybrid Editing Mode (Vi + Emacs Insert)**:
   - Full Vi modal editing enabled (`fish_vi_key_bindings`) with standard Emacs navigation preserved in insert mode.
   - Custom binding `Ctrl + J` in insert mode accepts autosuggestions instantly without leaving the home row.

---

## ⚡ Fish Shell & Plugin Stack

- **Fisher Package Manager**: Auto-bootstrapped on first run (`jorgebucaran/fisher`).
- **Active Plugins**:
  - `jorgebucaran/nvm.fish`: Native, reactive Node.js version management without subshell overhead.
- **Carapace Lazy-Bridge (2,380+ Commands)**:
  - Generates lightweight stubs on initialization, delegating autocompletion to Carapace on-demand with `<50ms` shell launch time.
- **Atuin History Search**:
  - Bound to `Ctrl + R`. Full-text search with execution durations, exit codes, and cross-machine encrypted sync.
- **Zoxide Navigation**:
  - `z <query>` for lightning-fast directory jumping based on frequency and recency.

---

## 🎨 Starship Prompt & Visual Theming

Configured in `~/.config/starship.toml` with an ergonomic **2-line layout**:

- **Line 1**: `Directory (5-level truncation)` ➔ `Git Branch ()` ➔ `Git Status (! + ? ⇡ ⇣)` ➔ `Execution Duration (>2s)`
- **Line 2**: `Prompt Character (❯)` (Green on success, Red on error).
- **Color Palette**: Harmonized with _Kanagawa Wave / Everforest_ (Foreground `#F3F6F9`, Cyan `#7AA89F`, Yellow `#FFE066`, Purple `#A3B5D6`).

---

## 🖥️ Kitty Terminal & Shader Effects

Configured in `~/.config/kitty/kitty.conf`:

- **Ghostty-Style Cursor Trail**: Powered by Kitty shaders (`cursor_trail 3`, `cursor_trail_decay 0.1 0.4`).
- **Glass Window Blur**: 75% background opacity (`background_opacity 0.75`) with 20px Wayland blur (`background_blur 20`).
- **Neovim & LSP Optimizations**: Undercurl support (`undercurl_style thin-sparse`), 10ms repaint delay, 3ms input latency, and UNIX socket control (`listen_on unix:/tmp/kitty`).
- **Typography**: JetBrainsMono Nerd Font @ 14.0pt with ligatures.

---

## 🛠️ CLI Tools, Aliases & Functions

### Core Aliases

```fish
alias cat='bat'
alias ls='eza --icons --color=auto'
alias ll='eza -la --icons --color=auto --group-directories-first'
alias tree='eza --tree --icons'
alias fzfbat='fzf --preview="bat --theme=gruvbox-dark --color=always {}"'
alias fzfnvim='nvim (fzf --preview="bat --theme=gruvbox-dark --color=always {}")'
```

### Custom Utility Functions

- **Fastfetch Diagnostics**:
  - Non-blocking display on initial interactive prompt showing OS, kernel, uptime, packages, disk partitions, and real-time CPU temperatures.
- **Modern CLI Integration**:
  - `eza` directory listing with Nerd Font icons.
  - `bat` syntax highlighting engine with Kanagawa palette.
  - `fzf` fuzzy interactive finder integrated with preview buffers.

---

## ⌨️ Keybindings Matrix

| Shortcut                 | Action                              | Context / Tool   |
| ------------------------ | ----------------------------------- | ---------------- |
| `Ctrl + R`               | Interactive fuzzy history search    | Atuin            |
| `Tab`                    | Autocomplete flags & arguments      | Carapace / Fish  |
| `Ctrl + J` / `Ctrl + F`  | Accept autosuggestion inline        | Fish Insert Mode |
| `Ctrl + A`               | Agent & terminal multiplexer prefix | Herdr            |
| `Alt + Left/Right`       | Move cursor by word                 | Fish             |
| `Ctrl + Shift + T`       | New Kitty Tab                       | Kitty            |
| `Ctrl + Shift + Enter`   | Split Kitty Window                  | Kitty            |
| `Ctrl + Shift + C` / `V` | System Clipboard Copy / Paste       | Kitty            |

---

## ⚡ Installation & Setup

### Via the Umbrella Repository (Recommended)

```bash
git clone --recurse-submodules https://github.com/blak0p/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh --fish
```

### Standalone Installation

```bash
git clone https://github.com/blak0p/dotfiles-shell.git ~/.config/dotfiles-shell
cd ~/.config/dotfiles-shell
bash deps/install-deps.sh
./install.sh
```

---

## 🔒 Private Configuration (`fish.custom`)

The installer initializes `~/.config/fish.custom`. This file is **never tracked by git** and is automatically evaluated by `config.fish`. Use it for:

- Secret API tokens (GitHub, OpenAI, Anthropic).
- Machine-specific aliases and custom PATH exports.

---

## 🙏 Credits & Lineage

This shell and terminal configuration is built upon the foundation of [**Gentleman Programming / Gentleman.Dots**](https://github.com/Gentleman-Programming/Gentleman.Dots), enhanced with Carapace lazy autocompletion for 2,380+ tools, Atuin SQLite history, Kitty GPU shader cursor trails.

---

## 📄 License

MIT License. Designed and maintained by **blak0p**.
