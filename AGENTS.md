# Dotfiles — Agent Guidelines & Skills Index

When working on this repository or any of its submodules, follow these core principles and workflows:

## Core Rules for Agents

1. **Multi-Repo / Submodule Integrity**:
   - Never commit child submodule changes directly into the superproject root.
   - When modifying submodule configs, commit in the child repository first (`dotfiles-hyprland`, `dotfiles-shell`, `dotfiles-editors`), then update the pointer in this superproject.
2. **Issue-First Workflow**:
   - Every change must reference an approved GitHub issue (`status:approved`).
3. **Commit Hygiene**:
   - Use Conventional Commits (`feat:`, `fix:`, `chore:`, `docs:`, etc.).
   - **Never** add `Co-Authored-By` or AI attribution trailers.
4. **Shell Script Standards**:
   - All shell scripts must use `set -eEuo pipefail` where appropriate.
   - Must pass `shellcheck` without warnings or suppressions unless documented.
5. **Idempotency & Safety**:
   - Dotfile symlink and deployment scripts must be idempotent (safe to run multiple times without corrupting state).
