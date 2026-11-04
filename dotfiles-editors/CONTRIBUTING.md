# Contributing to dotfiles-editors

Thanks for contributing! This module manages the editor configurations (Neovim / LazyVim).

## Contribution Workflow

```
Open Issue → Get status:approved → Open PR → Add type:* label → Review & Merge
```

### Critical Rules

1. **Issue-First**: Every PR must link an approved issue (`Closes #N`).
2. **Branch Naming**: `feat/*`, `fix/*`, `chore/*`, `docs/*`, `refactor/*`.
3. **Commit Hygiene**: Conventional Commits only (`feat:`, `fix:`, `chore:`, etc.). **No** `Co-Authored-By` trailers.
4. **ShellCheck**: All scripts in `deps/` or `install.sh` must pass ShellCheck.

### PR Lifecycle in Multi-Repo

When your PR is merged into `main` here, update the submodule pointer in the umbrella [`dotfiles`](https://github.com/blak0p/dotfiles) repository.
