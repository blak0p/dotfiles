# Project Rules — dotfiles

## Engram Hygiene
- **Saves**: Always use `project: "dotfiles"` for `mem_save`.
- **Searches**: Perform broad searches across all projects when looking for context or previous decisions.

## Safety & Permissions
- **Filesystem Writes**: You MUST notify the user and obtain explicit "OK" or confirmation before writing, updating, or deleting any file on the host filesystem.
- **Exceptions**: Temporary files in `/tmp` or internal memory artifacts are allowed, but anything in `/home` or system dirs requires confirmation.
