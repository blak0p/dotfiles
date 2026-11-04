# Dotfiles — Agent Guidelines & Skills Index

When working on this repository, follow these core principles and workflows:

## Core Rules for Agents

1. **Monorepo Layout**:
   - `dotfiles-hyprland/`, `dotfiles-shell/` and `dotfiles-editors/` are plain directories of this repository, not submodules.
   - Keep these directory names stable: deployed `~/.config` symlinks point into them.
   - A change that spans components goes in one commit or PR here.
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
