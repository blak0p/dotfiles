# Tasks: Patch Starship Container ID

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~1100 (mostly deletions) |
| 400-line budget risk | High |
| Chained PRs recommended | No |
| Suggested split | size:exception (single delivery batch) |
| Delivery strategy | single-pr |
| Chain strategy | size-exception |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: size-exception
400-line budget risk: High

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | Full cleanup, patch integration, and shortcut setup | PR 1 | Single PR containing cleanup and implementation |

## Phase 1: Cleanup / Legacy Deletions

- [ ] 1.1 Delete [fish](file:///home/alejandro/dev/dotfiles/home/.config/fish) directory and its files.
- [ ] 1.2 Delete [starship.toml](file:///home/alejandro/dev/dotfiles/home/.config/starship.toml).
- [ ] 1.3 Delete [nvim](file:///home/alejandro/dev/dotfiles/home/.config/nvim) directory.
- [ ] 1.4 Delete [zellij](file:///home/alejandro/dev/dotfiles/home/.config/zellij) directory.
- [ ] 1.5 Delete typo file [starship.tom](file:///home/alejandro/dev/dotfiles/modules/prompt/config/starship.tom).
- [ ] 1.6 Delete typo file [starship.tomls](file:///home/alejandro/dev/dotfiles/modules/prompt/config/starship.tomls).

## Phase 2: Python Patcher script

- [ ] 2.1 Create [patch_starship.py](file:///home/alejandro/dev/dotfiles/modules/prompt/config/patch_starship.py) to append container ID custom TOML block.

## Phase 3: Fish Hook script

- [ ] 3.1 Create [patch_starship.fish](file:///home/alejandro/dev/dotfiles/modules/prompt/config/patch_starship.fish) to truncate container ID and manage cache.

## Phase 4: Installer modifications

- [ ] 4.1 Update [install.sh](file:///home/alejandro/dev/dotfiles/modules/prompt/install.sh) to link hook to fish folder and python script.

## Phase 5: Doctor diagnostics modification

- [ ] 5.1 Modify [doctor.sh](file:///home/alejandro/dev/dotfiles/doctor.sh) to remove starship.tom check and add checks for new scripts.

## Phase 6: Verification and testing checks

- [ ] 6.1 Test: Verify [patch_starship.py](file:///home/alejandro/dev/dotfiles/modules/prompt/config/patch_starship.py) correctly appends the custom env block.
- [ ] 6.2 Test: Verify [patch_starship.fish](file:///home/alejandro/dev/dotfiles/modules/prompt/config/patch_starship.fish) works when CONTAINER_ID is set (truncation check) and unset.
- [ ] 6.3 Test: Verify fallback behavior to `/tmp` on cache write failures.
- [ ] 6.4 Test: Run [doctor.sh](file:///home/alejandro/dev/dotfiles/doctor.sh) to confirm no errors/warnings for prompt modules.
