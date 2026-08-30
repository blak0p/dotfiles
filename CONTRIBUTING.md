# Contributing to Dotfiles

Thanks for contributing to the dotfiles ecosystem. We enforce a strict **issue-first workflow** and a structured **multi-repo submodule lifecycle** — every change starts with an approved issue.

---

## 🏗️ Architecture & Multi-Repo Model

This repository is an **umbrella / superproject** containing git submodules:

- [`dotfiles-hyprland`](https://github.com/blak0p/dotfiles-hyprland) — Wayland & Hyprland desktop environment
- [`dotfiles-shell`](https://github.com/blak0p/dotfiles-shell) — Shell configurations (Fish, Kitty, Starship, CLI tools)
- [`dotfiles-editors`](https://github.com/blak0p/dotfiles-editors) — Editor configurations (Neovim / LazyVim)

### Bottom-Up PR Lifecycle

Git submodules store a commit pointer (SHA), not actual code inside the superproject tree. Therefore, changes must follow a bottom-up order:

```
1. Child Repo Issue & PR  ──► Merge into child main
                                      │
2. Superproject PR        ◄───────────┘
   (updates submodule SHA pointer)
```

1. **Child Repo PR**: Open and merge PRs in the respective child repository first (e.g. `dotfiles-shell`).
2. **Superproject PR**: Update the submodule pointer in this superproject repository (`git submodule update --remote <submodule>`), commit with `chore(submodules): update <submodule> pointer`, and open a PR here.

> ⚠️ **Critical Rule**: Never submit a superproject PR pointing to an unmerged commit on a personal branch in a child repo. The commit MUST already exist on the child's `main` branch.

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
| Chore | `chore/<description>` | `chore/bump-hyprland-submodule` |
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
2. Implement your changes or bump submodules.
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
| **Submodules Integrity** | All submodules initialize and checkout cleanly |

All checks must pass before a PR can be merged.

---

## 🏷️ Label System

### Type Labels (required on every PR — choose exactly one)

| Label | Color | Purpose |
|-------|-------|---------|
| `type:bug` | 🔴 | Bug fixes |
| `type:feature` | 🔵 | New features or configurations |
| `type:submodule` | 🟣 | Submodule pointer updates |
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
