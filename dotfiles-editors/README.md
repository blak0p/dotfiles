# ⚡ dotfiles-editors

<p align="center">
  <img src="assets/nvim-banner.png" alt="Neovim Banner" width="100%" onerror="this.style.display='none'"/>
</p>

<p align="center">
  <a href="https://neovim.io"><img src="https://img.shields.io/badge/Neovim-0.10+-57A143?style=for-the-badge&logo=neovim&logoColor=white" alt="Neovim"/></a>
  <a href="https://www.lazyvim.org"><img src="https://img.shields.io/badge/LazyVim-Distribution-blue?style=for-the-badge" alt="LazyVim"/></a>
  <a href="https://lua.org"><img src="https://img.shields.io/badge/Lua-5.1-000080?style=for-the-badge&logo=lua&logoColor=white" alt="Lua"/></a>
</p>

<p align="center">
  A blazing fast, modular, and production-grade <b>Neovim (v0.10+)</b> IDE built on <b>LazyVim</b>. Tailored for Fullstack engineering (TypeScript, React, Angular monorepos, Go workspaces, Rust, Python, Nix), featuring floating terminal integration, universal project execution, AI coding assistants, and seamless container/Tmux navigation.
</p>

Part of the [dotfiles umbrella](https://github.com/blak0p/dotfiles).

---

## 🎬 Editor Showcase

> [!TIP]
> Recorded showcase clips and demos are stored in `assets/nvim-demo.mp4` and `assets/nvim-demo.gif`.

<p align="center">
  <img src="assets/nvim-demo.gif" alt="Neovim Showcase Demo" width="90%" onerror="this.style.display='none'"/>
</p>

---

## 📋 Table of Contents

- [What Gets Deployed](#what-gets-deployed)
- [Architecture & Core Systems](#architecture--core-systems)
- [Plugin Ecosystem & Key Modules](#plugin-ecosystem--key-modules)
- [Visual Aesthetics & UI Customization](#visual-aesthetics--ui-customization)
- [Keybindings (Cheat Sheet)](#keybindings-cheat-sheet)
- [Installation & Setup](#installation--setup)
- [Troubleshooting & FAQ](#troubleshooting--faq)

---

## 📦 What Gets Deployed

The installer symlinks this repository directly into `~/.config/nvim`:

| Path | Configures | Description |
|---|---|---|
| `~/.config/nvim` | Neovim IDE | Modular LazyVim configuration, custom plugin specs, themes, and keymaps |

---

## 🏗️ Architecture & Core Systems

### 1. System Node.js Isolator (`lua/config/nodejs.lua`)
* **Problem Solved**: Legacy projects using older Node versions (`< v18`) often break modern Language Servers (LSP) and Node-dependent Neovim plugins.
* **Mechanism**: Automatically cascades and prioritizes modern system Node runtimes from Volta (`~/.volta/bin/node`), NVM, Nix, Homebrew (`/opt/homebrew`, `/usr/local/bin`), and `/usr/bin/node`.
* **Commands**: `:NodeRefresh`, `:NodeInfo`, `:NodeDebug`.

### 2. Cross-Container & Remote Clipboard (`lua/config/lazy.lua`)
* **OSC 52 Synchronization**: Uses `vim.ui.clipboard.osc52` to synchronize your system clipboard directly over terminal ANSI sequences across SSH sessions, Distrobox containers, and remote tmux environments without requiring X11/Wayland forwarding.
* **WSL Auto-Bridge**: Detects WSL and hooks `win32yank.exe` automatically.

### 3. Ergonomics & Clean Visuals (`lua/config/options.lua`)
* **Minimalist End-of-Buffer**: `fillchars:append({ eob = " " })` strips distracting `~` tildes.
* **Responsive Key Latency**: `timeoutlen = 1000`, `ttimeoutlen = 0` for instantaneous multi-key chords.

---

## 🧩 Plugin Ecosystem & Key Modules

### A. Navigation & Filesystem Editing
* **Oil.nvim (`stevearc/oil.nvim`)**:
  * Edit your directory structure like a standard text buffer (`-` or `<leader>-`). Rename, move, create, and delete files with standard Vim operations (`cw`, visual select, `:w`).
  * Open in floating popup via `<leader>E`.
* **Snacks.nvim Picker (`folke/snacks.nvim`)**:
  * Blazing fast file search (`<leader>ff`), buffer switching (`<leader>fb`), and live grep (`<leader>sg`).
* **Vim-Tmux-Navigation**:
  * Seamless `<Ctrl + h/j/k/l>` movement between Neovim window splits and external Tmux panes.

### B. Autocompletion, LSP & Formatting
* **Blink.cmp (`saghen/blink.cmp`)**:
  * Next-generation completion engine with `<C-j>` / `<C-k>` navigation, instant fuzzy sorting, and snippet expansion (`<Tab>`).
* **Lspconfig**:
  * **Angular Language Server (`angularls`)**: Smart root directory resolver for monorepos and Nx workspaces (`angular.json`, `project.json`).
  * **Nix LSP (`nil_ls`)**: Declarative Nix language formatting.
* **Mini.hipatterns**:
  * Real-time inline color previews for Hexadecimal and `hsl(...)` color strings computed via internal mathematical converters.

### C. Inspection, Git & PR Review
* **Goto-Preview (`rmagatti/goto-preview`)**:
  * Peek definitions (`gpd`), declarations (`gpD`), implementations (`gpi`), and references (`gpr`) in interactive floating windows without losing your cursor position. Close all previews with `gP`.
* **Diffview (`sindrets/diffview.nvim`)**:
  * Side-by-side git diff inspection (`<leader>dv`).
  * **PR Audit Feature**: Press `m` in the file tree to mark reviewed files with a persistent green checkmark (`✓`).
* **LazyGit (`<leader>gg`)**: Floating terminal instance of LazyGit.

### D. Task Execution & AI Assistants
* **UniRunner (`sheymor21/unirunner.nvim`)**:
  * Context-aware universal test and task runner (`<leader>jr`, `<leader>js`). Auto-detects Go workspaces (`go.work`), Cargo, NPM/PNPM scripts, Justfiles, and Makefiles.
* **Claude Code Integration (`<leader>ac`)**:
  * Built-in Claude Code assistant deployed on a 30% left split. Send buffers with `<leader>ab`, selection with `<leader>as`, and accept diffs with `<leader>aa`.

---

## 🎨 Visual Aesthetics & UI Customization

| Component | Technology | Description |
|---|---|---|
| **Theme** | `gentleman-kanagawa-blur` | Deep dark palette inspired by Kanagawa Wave with full transparency support |
| **Breadcrumbs** | `b0o/incline.nvim` | Floating pills in the top-right corner of active splits showing devicon, filename, and `[+]` modified state |
| **Statusline** | `nvim-lualine/lualine.nvim` | Minimalist status bar displaying mode badges, git status, and Oil.nvim paths |
| **Dashboard** | `folke/snacks.nvim` | ASCII header with quick project jumpers and plugin statistics |
| **Markdown** | `render-markdown.nvim` | Circular badge headings (①, ②, ③), nested bullet glyphs, and interactive checkboxes |
| **Keystroke Streamer** | `screenkey.nvim` | Live keystroke visualizer (`<leader>uk`) for tutorials and screen recordings |

---

## ⌨️ Keybindings (Cheat Sheet)

### Navigation, Splits & Terminals
| Shortcut | Action | Description |
|---|---|---|
| `<leader>ft` (`Space + f + t`) | **Floating Terminal** | Rounded popup terminal running default shell |
| `<Ctrl + />` | **Toggle Terminal** | Bottom integrated terminal |
| `-` / `<leader>-` | **Oil File Manager** | Edit parent directory as a buffer |
| `<leader>E` | **Oil Floating** | Open Oil.nvim in a centered popup |
| `<Ctrl + h/j/k/l>` | **Navigate Splits/Tmux** | Move between Neovim splits and Tmux panes |
| `<leader>\` / `<leader>-` | **Split Window** | Vertical / horizontal window splits |
| `<leader>bq` | **Close Other Buffers** | Closes all open buffers except the active one |
| `<Ctrl + s>` | **Quiet Save** | Saves buffer with notification feedback |

### Search & Substitution
| Shortcut | Action | Description |
|---|---|---|
| `<leader>ff` | **Find Files** | Fast project search via Snacks Picker |
| `<leader>fb` | **Find Buffers** | Switch between open buffers |
| `<leader>sg` *(Visual)* | **Live Grep Selection** | Grep selected text across the project |
| `<leader>fs` | **Rip-Substitute** | Interactive Ripgrep-powered find & replace |

### Code Inspection & Goto-Preview
| Shortcut | Action | Description |
|---|---|---|
| `gpd` | **Preview Definition** | Floating preview of function/variable definition |
| `gpD` | **Preview Declaration** | Floating preview of declaration |
| `gpi` | **Preview Implementation** | Floating preview of interface implementation |
| `gpr` | **Preview References** | Floating preview of all code references |
| `gP` | **Close All Previews** | Dismisses all floating preview windows |
| `<leader>cs` | **Symbols Outline** | Toggles code symbol tree |

### Git & Code Review
| Shortcut | Action | Description |
|---|---|---|
| `<leader>gg` | **LazyGit** | Floating LazyGit terminal |
| `<leader>gb` | **Git Blame** | Floating line blame |
| `<leader>go` | **Open in Web** | Opens file/line on GitHub/GitLab |
| `<leader>dv` | **Diffview** | Opens Git diff split |
| `m` *(in Diffview)* | **Mark Reviewed** | Toggles green checkmark (`✓`) on reviewed file |

### Task Runner (UniRunner) & AI (Claude Code)
| Shortcut | Action | Description |
|---|---|---|
| `<leader>jr` | **Run Project Task** | Executes auto-detected test/build command |
| `<leader>js` | **Select Task** | Command selector for Go/Cargo/NPM/Just |
| `<leader>ac` | **Toggle Claude Code** | Toggles AI console in 30% left split |
| `<leader>ab` | **Add Buffer to Claude** | Sends current buffer to AI context |
| `<leader>aa` / `<leader>ad` | **Accept / Deny Diff** | Resolves AI code suggestions |

---

## ⚡ Installation & Setup

### Via the Umbrella Repository (Recommended)
```bash
git clone --recurse-submodules https://github.com/blak0p/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh --nvim
```

### Standalone Installation
```bash
git clone https://github.com/blak0p/dotfiles-editors.git ~/.config/nvim
bash deps/install-deps.sh
nvim
```

---

## 🔧 Troubleshooting & FAQ

### Node.js LSP not loading on older projects
Run `:NodeInfo` or `:NodeRefresh` to force Neovim to lock onto the isolated system Node binary rather than an older project-local Node version.

### Missing glyphs or icons
Ensure your terminal font is set to a patched **Nerd Font** (such as *JetBrainsMono Nerd Font*).

---

## 📄 License

MIT License. Designed and maintained by **blak0p**.
