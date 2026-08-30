<!-- 
  ⚠️ READ BEFORE SUBMITTING
  
  Every PR must:
  1. Link an approved issue (with status:approved label)
  2. Have exactly one type:* label
  3. Pass all automated checks
  4. Follow Conventional Commits (no Co-Authored-By trailers)
  
  See CONTRIBUTING.md for the full multi-repo workflow.
-->

## 🔗 Linked Issue

<!-- REQUIRED: Replace the # below with the issue number. -->
<!-- Automated check: "Check Issue Reference" verifies this exists. -->
<!-- Automated check: "Check Issue Has status:approved" verifies the issue is approved. -->

Closes #

---

## 🏷️ PR Type

<!-- REQUIRED: Check exactly ONE type below, then add the matching label to the PR. -->
<!-- Automated check: "Check PR Has type:* Label" verifies the label exists. -->

- [ ] `type:bug` — Bug fix
- [ ] `type:feature` — New feature or module support
- [ ] `type:submodule` — Submodule pointer update (e.g. hyprland, shell, editors)
- [ ] `type:docs` — Documentation only
- [ ] `type:refactor` — Code refactoring (no behavior change)
- [ ] `type:chore` — Maintenance, scripts, tooling
- [ ] `type:breaking-change` — Breaking change in installation or structure

---

## 📝 Summary

<!-- What does this PR do? Be concise — 1-3 bullet points. -->

- 

## 📂 Changes

<!-- Key files changed or submodules updated. -->

| Component / File | Change |
|------------------|--------|
| `path/to/file` | What changed |

## 🧪 Test Plan

<!-- How did you verify this works? -->

- [ ] Shell scripts validated with `make lint` / `shellcheck`
- [ ] Submodules initialize cleanly: `git submodule update --init --recursive`
- [ ] Tested installation script (`./install.sh --help` or specific flags)

<!-- Describe any manual testing steps: -->

---

## 🤖 Automated Checks

These run automatically and **all must pass** before merge:

| Check | What it verifies | Status |
|-------|-----------------|--------|
| **Check Issue Reference** | PR body contains `Closes #N` / `Fixes #N` / `Resolves #N` | ⏳ |
| **Check Issue Has status:approved** | Linked issue has `status:approved` label | ⏳ |
| **Check PR Has type:\* Label** | PR has exactly one `type:*` label | ⏳ |
| **ShellCheck & Lint** | `shellcheck` passes on all `.sh` scripts | ⏳ |
| **Submodules Integrity** | All submodules resolve and checkout cleanly | ⏳ |

---

## ✅ Contributor Checklist

- [ ] I linked an approved issue above (`Closes #N`)
- [ ] I added exactly **one** `type:*` label to this PR
- [ ] If updating submodules, child repository PRs have already been merged into `main`
- [ ] Ran linter/checks locally: `make check`
- [ ] Commits follow [conventional commits](https://www.conventionalcommits.org/) format
- [ ] No `Co-Authored-By` or AI attribution trailers in commits
- [ ] Documentation updated in `README.md` / `CONTRIBUTING.md` if necessary

---

## 💬 Notes for Reviewers

<!-- Optional: anything the reviewer should know — context, tradeoffs, open questions. -->
