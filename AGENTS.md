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

## Task Schema

- `id` - UUID (string)
- `title`, `description`, `status` (todo|in-progress|done)
- `priority` (1-3), `created_at`, `updated_at`

## Notes

- Database is per-project in `.todo.db` - commit it to share with team
- Add `.todo.db` to `.gitignore` if you prefer local-only data
