# bash-scripts

Portable shell scripts for common development tasks.

## Quick Start

```bash
./init-todo.sh
./init-todo.sh --install-global  # Also add alias to ~/.bashrc
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

- bash 4+
- sqlite3
