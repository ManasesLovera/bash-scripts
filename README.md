# bash-scripts

Portable shell scripts for common development tasks.

## Quick Start

### Tasks CLI (`todo`)
```bash
./init-todo.sh
./init-todo.sh --install-global  # Also add alias to ~/.bashrc
```

### Antigravity Installer
```bash
sudo bash install-antigravity-all.sh
```

## Commands

### Tasks

```bash
todo add "Task title" [--pri 1-3]
todo list [--all|--done]
todo get <uuid>
todo start|done <uuid>
todo update <uuid> --title "..." --desc "..." --pri N --status todo|in-progress|done
todo delete <uuid>
```

### Projects (Multi-Project Support)

```bash
todo projects list      # Find all .todo.db files
todo projects current   # Show current project
todo projects switch /path/to/project   # Switch to project
```

### Antigravity Installer

The `install-antigravity-all.sh` script installs and configures:
1. **Antigravity 2.0 Desktop App**:
   - Launch command: `antigravity`
   - Installation path: `/opt/antigravity`
   - Symlink: `/usr/local/bin/antigravity`
2. **Antigravity IDE**:
   - Launch command: `antigravity-ide`
   - Installation path: `/opt/antigravity-ide`
   - Symlink: `/usr/local/bin/antigravity-ide`

Both components are registered as desktop applications (with `.desktop` files, menu icons, and MIME-type handling for the IDE). Upgrades automatically backup the existing installation folder to `.previous` for safety.

## Database Location

Each project stores data in `<project_root>/.todo.db`.

- Commit `.todo.db` to share tasks with team
- Or add it to `.gitignore` for local-only data

## Project Detection

1. Explicit switch (`todo projects switch`)
2. Git repository root
3. `.todo-project` marker file
4. Current working directory

## Requirements

### Tasks CLI (`todo`)
- bash 4+
- sqlite3

### Antigravity Installer (`install-antigravity-all.sh`)
- Ubuntu 24.04 LTS (or compatible Debian-based Linux)
- `sudo` privileges
- `curl`, `tar`, `desktop-file-utils`, `python3` (automatically installed via `apt` if missing)
