<!-- 
  ⚠️ READ BEFORE SUBMITTING
  
  Every PR must:
  1. Link an approved issue (with status:approved label)
  2. Have exactly one type:* label
  3. Pass all automated checks
  4. Follow Conventional Commits (no Co-Authored-By trailers)
  
  See CONTRIBUTING.md for the full contribution workflow.
-->

## 🔗 Linked Issue

Closes #

---

## 🏷️ PR Type

- [ ] `type:bug` — Bug fix
- [ ] `type:feature` — New editor plugin, keybinding, or tool integration
- [ ] `type:docs` — Documentation only
- [ ] `type:refactor` — Code or config refactoring (no behavior change)
- [ ] `type:chore` — Maintenance, scripts, tooling
- [ ] `type:breaking-change` — Breaking change in Neovim/LazyVim configuration

---

## 📝 Summary

<!-- What does this PR do? Be concise — 1-3 bullet points. -->

- 

## 📂 Changes

| Component / File | Change |
|------------------|--------|
| `path/to/file` | What changed |

## 🧪 Test Plan

<!-- How did you verify this works? -->

- [ ] Neovim boots cleanly: `nvim --headless "+Lazy! sync" +qa`
- [ ] Shell scripts validated with `make lint` / `shellcheck`
- [ ] Checked LSP / formatters / keybindings

---

## ✅ Contributor Checklist

- [ ] I linked an approved issue above (`Closes #N`)
- [ ] I added exactly **one** `type:*` label to this PR
- [ ] Commits follow [conventional commits](https://www.conventionalcommits.org/) format
- [ ] No `Co-Authored-By` or AI attribution trailers in commits
- [ ] Documentation updated in `README.md` if necessary
