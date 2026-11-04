# Contributing to dotfiles-hyprland

Thanks for contributing! This module manages the Wayland & Hyprland desktop environment configs.

## Contribution Workflow

```
Open Issue → Get status:approved → Open PR → Add type:* label → Review & Merge
```

### Critical Rules

1. **Issue-First**: Every PR must link an approved issue (`Closes #N`).
2. **Branch Naming**: `feat/*`, `fix/*`, `chore/*`, `docs/*`, `refactor/*`.
3. **Commit Hygiene**: Conventional Commits only (`feat:`, `fix:`, `chore:`, etc.). **No** `Co-Authored-By` trailers.
4. **ShellCheck**: All scripts in `deps/` or `install.sh` must pass ShellCheck.

### Where to Contribute

This component lives in the [`dotfiles`](https://github.com/blak0p/dotfiles) monorepo. Open issues and PRs there; changes to `dotfiles-hyprland/` ship in the same PR as any related root changes.
