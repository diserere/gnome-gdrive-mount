# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

`gnome-gdrive-mount` is a tiny Linux/GNOME utility for mounting Google Drive via `rclone`. It consists of:

- `src/gdrive-mount` — a bash script (entry point) that mounts/unmounts the Google Drive remote `gdrive:` at `$HOME/GoogleDrive` using `rclone mount --vfs-cache-mode writes`.
- `src/rclone-gdrive.desktop` — a GNOME `.desktop` file that exposes the script as a launcher with an "Unmount" right-click action. Install it under `~/.local/share/applications/` to surface it in the GNOME application menu.

The script and `.desktop` file are both written in Russian (UI strings, help text). Preserve Russian-language user-facing strings unless asked to translate.

## Repository layout

```
src/
  gdrive-mount             # bash script — mount/unmount logic
  rclone-gdrive.desktop    # GNOME application entry
README.md                  # (empty)
```

No build system, no package manifest, no test framework, no linter — the deliverables are the script and the desktop file as-is.

## Prerequisites

- `rclone` configured with a remote literally named `gdrive:` (configured via `rclone config`).
- `fusermount` (from `fuse` package) for unmounting.
- `mountpoint` (from `util-linux`) for mount-state checks.

## Common commands

There is no build step. The script is run directly.

**Make it executable** (after cloning or editing):
```
chmod +x src/gdrive-mount
```

**Run locally**:
```
./src/gdrive-mount          # mount gdrive: at $HOME/GoogleDrive
./src/gdrive-mount -u       # unmount
./src/gdrive-mount -h       # help
```

**Install the launcher for the current user**:
```
install -m 755 src/gdrive-mount ~/.local/bin/gdrive-mount
install -m 644 src/rclone-gdrive.desktop ~/.local/share/applications/
```

## Key behavior to preserve

- The mount point is hard-coded to `$HOME/GoogleDrive` and the remote is hard-coded to `gdrive:` at the top of the script. If you make these configurable, keep the existing defaults to avoid breaking installed `.desktop` files that invoke `gdrive-mount` with no arguments.
- The script runs `rclone mount ... &` in the background and only sleeps 1 second before checking `mountpoint -q`. Don't change this to a blocking invocation — the script is meant to return quickly so the `.desktop` launcher doesn't hang.
- On unmount, the script removes the mount-point directory only if it's empty (`rmdir`, not `rm -rf`).
- The mount path is refused if the directory exists and is non-empty (to avoid letting rclone shadow local files).
- Exit codes: `0` on success/idempotent re-mount, `1` on real failure (unmount failed because files are open, or mount point non-empty).

## Conventions

- Shell style in `gdrive-mount`: lower-case function names, `case "$1"` for arg parsing, `set -e` is intentionally NOT used (the script handles errors with explicit `if` checks and user-facing messages).
- `.desktop` file uses `Terminal=false` and `StartupNotify=false`. The Unmount action invokes `gdrive-mount -u` directly.
