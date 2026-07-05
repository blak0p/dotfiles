## Intent

Provide dynamic Distrobox container context in the Starship prompt for shared `$HOME` environments. On the host, the default prompt is retained to avoid startup overhead. In containers, a truncated container ID is displayed. Additionally, integrate a custom Fish shortcut `d` to enter the Distrobox `dev` container directly inside the `~/dev` directory.

## Scope

### In Scope
- Hook in Fish (`home/.config/fish/conf.d/patch_starship.fish`) calling a Python patcher helper if `$CONTAINER_ID` is set.
- Python helper script `home/.config/fish/conf.d/patch_starship.py` to append `[env_var.CONTAINER_ID]` configuration and insert `$env_var.CONTAINER_ID` after `$directory` in the format string.
- Truncate long 64-character container IDs to 12 characters.
- Fallback caching using `test -nt` to compare `starship.toml` and custom config.
- Cache to `~/.cache/starship/starship_custom.toml`, falling back to `/tmp/starship_custom.toml` if not writable.
- Fish function `d` (`modules/prompt/config/d.fish`) to enter distrobox `dev` container landing in `~/dev` directory.
- Remove old typo files: `modules/prompt/config/starship.tom` and `modules/prompt/config/starship.tomls`.
- Update `modules/prompt/install.sh` to remove old files links and link new fish/python script files, including the `d.fish` function.
- Update `doctor.sh` to clean up the legacy checks.

### Out of Scope
- Prompt patching for Zsh, Bash, or other shells.
- Dynamic patching for other environment variables.

## Capabilities

## New Capabilities
- `starship-container-id`: Dynamic patching of starship prompt layout inside containers to display the container identifier.
- `distrobox-shortcut`: Fast shell function `d` to jump directly into the distrobox `dev` container inside the `~/dev` folder.

### Modified Capabilities
None

## Approach

1. **Fish Hook**: Checks if `$CONTAINER_ID` is defined. If yes, runs a file-age comparison (`-nt`) between the base config (`~/.config/starship.toml`) and cached config (`~/.cache/starship/starship_custom.toml` or `/tmp/starship_custom.toml`).
2. **Python Helper**: If base is newer or cache is missing, reads base config, truncates `CONTAINER_ID` to 12 chars if hex, appends `[env_var.CONTAINER_ID]` definition, appends `$env_var.CONTAINER_ID` after `$directory` in the `format` string, and writes to cache.
3. **Shell Environment**: Fish hook sets `STARSHIP_CONFIG` to the patched config.
4. **Distrobox Function**: A Fish function `d` defined as `distrobox enter dev --workdir ~/dev $argv`.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `home/.config/fish/conf.d/patch_starship.fish` | New | Shell startup hook executing caching logic. |
| `home/.config/fish/conf.d/patch_starship.py` | New | Patcher appending custom container prompt block. |
| `modules/prompt/config/d.fish` | New | Custom Fish function shortcut to enter distrobox. |
| `modules/prompt/config/starship.tom` | Removed | Delete legacy/typo file. |
| `modules/prompt/config/starship.tomls` | Removed | Delete legacy/typo file. |
| `modules/prompt/install.sh` | Modified | Update symlink configuration for prompt module. |
| `doctor.sh` | Modified | Remove legacy starship symlink verification. |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Shell startup latency | Low | Cache using `test -nt` avoids invoking Python on subsequent startup. |
| Read-only filesystems | Low | Fall back to `/tmp` if cache directory is not writable. |

## Rollback Plan

1. Revert Git changes in `modules/prompt/install.sh` and `doctor.sh`.
2. Delete `home/.config/fish/conf.d/patch_starship.{fish,py}` and `~/.config/fish/functions/d.fish`.
3. Restore `starship.tom` and `starship.tomls` if needed (or simply delete their broken symlinks).
4. Run `install.sh` again to restore default symlinks.

## Dependencies

- Python 3.x interpreter.
- Starship prompt binary installed.
- Distrobox toolchain and a container named `dev` configured.

## Success Criteria

- [ ] Terminal startup does not run Python on the host shell or when `$CONTAINER_ID` is unset.
- [ ] Inside container with `CONTAINER_ID` set, `STARSHIP_CONFIG` is set and the prompt displays container ID (max 12 characters) right after the directory.
- [ ] Typing `d` enters the distrobox `dev` container directly inside the `~/dev` directory.
- [ ] No residual symlink warnings in `./doctor.sh`.
