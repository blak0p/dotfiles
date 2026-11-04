# Contributing to Dotfiles

Thanks for contributing to the dotfiles ecosystem. We enforce a strict **issue-first workflow** in a single **monorepo** — every change starts with an approved issue.

---

## 🏗️ Architecture

This repository is a **monorepo**. Each component is a top-level directory with its own installer:

- `dotfiles-hyprland/` — Wayland & Hyprland desktop environment (incl. the Quickshell `sky` shell)
- `dotfiles-shell/` — Shell configurations (Fish, Kitty, Starship, CLI tools)
- `dotfiles-editors/` — Editor configurations (Neovim / LazyVim)

A change that touches several components ships in one PR. Keep the directory names stable: deployed `~/.config` symlinks point into them.

---

## 📋 Contribution Workflow

```
Open Issue → Get status:approved → Open PR → Add type:* label → Review & Merge
```

### Step 1: Open an Issue

Use the correct template:
- **Bug Report** — for bugs or broken installation scripts
- **Feature Request** — for new features, modules, or configurations

> ⚠️ Blank issues are disabled. You must use a template.

### Step 2: Wait for Approval

A maintainer will review the issue and add the `status:approved` label if accepted.

**Do not open a PR until the issue is approved.** Automated checks will block PRs that reference unapproved issues.

### Step 3: Branch Naming

Branch names are validated and must follow the format:

**Pattern:** `^(feat|fix|chore|docs|style|refactor|perf|test|build|ci|revert)\/[a-z0-9._-]+$`

| Type | Branch pattern | Example |
|------|---------------|---------|
| Feature | `feat/<description>` | `feat/add-waybar-custom-modules` |
| Bug fix | `fix/<description>` | `fix/install-deps-arch` |
| Chore | `chore/<description>` | `chore/update-ci-actions` |
| Docs | `docs/<description>` | `docs/update-keybindings-guide` |
| Refactor | `refactor/<description>` | `refactor/modularize-bootstrap-host` |

### Step 4: Commit Hygiene

1. **Conventional Commits**: Every commit message must follow the Conventional Commits specification:
   ```
   <type>(<optional-scope>): <description>
   ```
   Allowed types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`.
2. **No AI Attribution**: Never include `Co-Authored-By` or AI attribution trailers in commit messages.
3. **Atomic Commits**: Keep one logical change per commit.

### Step 5: Open a Pull Request

Once the issue is approved:
1. Fork or branch from `master` / `main`.
2. Implement your changes.
3. Open a PR using the PR template — **link the approved issue** with `Closes #N`.
4. Add exactly **one `type:*` label** to the PR.

---

## 🤖 Automated PR Checks

Every PR triggers automated GitHub Actions checks:

| Check | What it verifies |
|-------|-----------------|
| **Check Issue Reference** | PR body contains `Closes #N`, `Fixes #N`, or `Resolves #N` |
| **Check Issue Has status:approved** | The linked issue has the `status:approved` label |
| **Check PR Has type:* Label** | PR has exactly one `type:*` label |
| **ShellCheck Lint** | All `.sh` scripts pass `shellcheck` without warnings |
| **Installer Smoke Check** | `./install.sh --help` runs cleanly |

All checks must pass before a PR can be merged.

---

## 🏷️ Label System

### Type Labels (required on every PR — choose exactly one)

| Label | Color | Purpose |
|-------|-------|---------|
| `type:bug` | 🔴 | Bug fixes |
| `type:feature` | 🔵 | New features or configurations |
| `type:docs` | 🔵 | Documentation changes |
| `type:refactor` | 🟣 | Refactoring without behavior change |
| `type:chore` | ⚪ | Maintenance, scripts, tooling |
| `type:breaking-change` | 🔴 | Breaking changes in structure or installation |

### Status Labels (managed by maintainers)

| Label | Meaning |
|-------|---------|
| `status:needs-review` | Awaiting maintainer review (auto-assigned) |
| `status:approved` | Approved for implementation — ready for PRs |
| `status:in-progress` | Actively being worked on |
| `status:blocked` | Blocked by external dependency or upstream issue |
| `status:stale` | Inactive for 30 days |
| `status:wontfix` | Decided not to fix or implement |
