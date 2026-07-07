# Agents

## Project Detection (Priority Order)

1. `~/.todo-sh/current_project` - explicitly switched project
2. Git root (`git rev-parse --show-toplevel`) if in a repo
3. `.todo-project` marker file in parent directories
4. Current directory as fallback

## Database Location

Each project has its database at `<project_root>/.todo.db`

## Key Commands

- `./init-todo.sh` - Initialize todo for current project
- `./init-todo.sh --install-global` - Install `todo` alias to `~/.bashrc`
- `todo projects list|switch|current` - Multi-project management
- `todo help` - Full command reference
- `sudo bash install-antigravity-all.sh` - Install/update Antigravity 2.0 Desktop App and Antigravity IDE

## Task Schema

- `id` - UUID (string)
- `title`, `description`, `status` (todo|in-progress|done)
- `priority` (1-3), `created_at`, `updated_at`

## Antigravity Installation Info

- **Prerequisites**: Ubuntu 24.04 LTS, `sudo` privileges. Installs `curl`, `tar`, `desktop-file-utils`, and `python3` via `apt` if missing.
- **Antigravity 2.0 Desktop App**:
  - Launch Command: `antigravity`
  - Binary Symlink: `/usr/local/bin/antigravity` -> `/opt/antigravity/Antigravity-<arch>/antigravity`
- **Antigravity IDE**:
  - Launch Command: `antigravity-ide`
  - Binary Symlink: `/usr/local/bin/antigravity-ide` -> `/opt/antigravity-ide/Antigravity-IDE/antigravity-ide`
- **Backup & Rollback**: Existing installations are preserved as `.previous` directories (e.g., `/opt/antigravity.previous`) when running updates.

## Notes

- Database is per-project in `.todo.db` - commit it to share with team
- Add `.todo.db` to `.gitignore` if you prefer local-only data
