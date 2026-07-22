# dotfiles

Umbrella repo for my public dotfiles. Each domain lives in its own repo and is wired in as a git submodule.

## Sub-repos

- [`dotfiles-hyprland`](https://github.com/blak0p/dotfiles-hyprland) — Hyprland desktop stack (hypr, waybar, quickshell, fuzzel, gtk, xsettingsd, systemd, btop, cava)
- [`dotfiles-shell`](https://github.com/blak0p/dotfiles-shell) — Shell + terminal (fish, starship, atuin, carapace, fastfetch, kitty)
- [`dotfiles-editors`](https://github.com/blak0p/dotfiles-editors) — Neovim

## Install

Clone with submodules:
```bash
git clone --recurse-submodules https://github.com/blak0p/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh --all
```

Or, if you forgot `--recurse-submodules`, the installer will auto-init on first run.

## Flags

- `--all` — deploy every sub-repo
- `--hyprland` — only the Hyprland stack
- `--fish` or `--kitty` — only the shell+terminal sub-repo
- `--nvim` — only the Neovim sub-repo
- `--help` — show usage

Each sub-repo can also be cloned standalone and installed with its own `./install.sh`.

## Update submodules

```bash
git pull
git submodule update --remote --merge
```

## Edit a submodule

```bash
cd dotfiles-shell
git checkout main
# make your changes, commit, push
git add . && git commit -m "..." && git push
cd ..
# then in the umbrella:
git add dotfiles-shell
git commit -m "chore(submodules): bump dotfiles-shell to <sha>"
```# test mié 22 jul 2026 10:35:11 CEST
