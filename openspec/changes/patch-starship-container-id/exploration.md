## Exploration: patch-starship-container-id

### Current State
Today, the dotfiles repository uses a modular structure where prompt configurations like `starship.toml` (located at `config/starship.toml` and `home/.config/starship.toml`) are statically defined and symlinked to user home directory locations. The shell configurations (like `config.fish` at `home/.config/fish/config.fish`) are managed centrally. Modifying the base files directly means any upstream updates from third-party dotfiles (e.g., Gentleman.Dots) will overwrite local changes, losing custom configurations like container detection and prompt modifications.

Currently, there is no dynamic checking or patching of `starship.toml` to display container context, nor is there a hook configured in fish to handle this dynamically.

### Affected Areas
- `home/.config/fish/conf.d/patch-starship.fish` — New file. Custom fish script that hooks into shell startup, detects `$CONTAINER_ID`, checks config age, and dynamically updates `STARSHIP_CONFIG`.
- `home/.config/fish/conf.d/patch_starship.py` — New file. Python helper script called by the fish hook to read the base config, perform safe string replacement to add the custom `container_id` module, and output the patched config file.

### Approaches

1. **Pure Fish Script (inline string replacement using sed)**
   - **Description**: Sourced directly by Fish on startup. Uses `sed` to locate `$directory` inside `~/.config/starship.toml`, replaces it with `${custom.container_id}$directory`, and appends the custom module definition before writing to a cached file.
   - **Pros**:
     - Extremely fast; doesn't invoke any heavy external interpreters during shell startup.
     - Self-contained in a single `.fish` file.
   - **Cons**:
     - `sed` syntax is brittle when handling multi-line strings or files with comments containing `$directory`.
     - Hard to maintain and debug regex parsing edge-cases directly in a fish shell script.
   - **Effort**: Low

2. **Fish Hook calling a Python Patcher (Uncached)**
   - **Description**: The fish hook detects `$CONTAINER_ID` and always invokes a Python helper script to read the base configuration, modify the content safely using Python's robust string methods, and save it to `~/.cache/starship/starship-patched.toml`.
   - **Pros**:
     - Safer and more readable parsing logic than `sed`.
     - Easily ignores comments or redundant patching attempts.
   - **Cons**:
     - Invoking Python on every interactive shell startup adds noticeable latency (~30-100ms) to terminal opening.
   - **Effort**: Low

3. **Fish Hook calling Python Patcher with File-Age Caching**
   - **Description**: The fish hook does a lightweight file age comparison using Fish built-ins (`test "$base_config" -nt "$patched_config"`). It only invokes the Python helper script if the cached patched config is missing or if the base configuration file is newer than the cache.
   - **Pros**:
     - Safe and robust parsing logic using Python.
     - Zero startup latency overhead for subsequent shell spawns because the Python script is bypassed if the cache is up-to-date.
   - **Cons**:
     - Requires maintaining two files (the fish hook and the python patcher script) in `conf.d/`.
   - **Effort**: Medium

### Recommendation
Option 3 is the recommended approach. It combines the safety and reliability of a Python script for TOML file patching with the speed of fish-native cache validation. This guarantees that user terminals load instantly while ensuring the custom prompt layout is automatically updated whenever the base starship config changes.

### Risks
- **Shell Startup Performance**: If the cache check is not correctly implemented, invoking Python on every startup can degrade shell responsiveness. This is mitigated by the file-age caching mechanism.
- **Base Config Format Changes**: If the base configuration completely removes `$directory` from the format string, the regex replacement will fail to insert the container ID module. This is mitigated by adding a fallback check in the Python script: if `$directory` is not found, prepend the custom module to the format, or fall back to the unpatched base config without crashing.

### Ready for Proposal
Yes — The proposed approach solves the problem robustly without changing third-party managed files. The orchestrator can proceed with proposing the task plan.

## Context Notes
- **Alternative considered**: Using the built-in `container` module in Starship. However, Starship's native `container` module is designed to display container runtime icons (like Docker, LXC, etc.) and does not easily extract or display specific environment variables like `$CONTAINER_ID` without defining custom commands.
- **Gotcha**: Placing files in `~/.config/fish/conf.d/` with extensions other than `.fish` (e.g. `.py` for the python helper) is perfectly safe because Fish's automatic loader only sources files ending with `.fish`. This allows keeping the python script in the same directory as the hook for cleaner organization.
