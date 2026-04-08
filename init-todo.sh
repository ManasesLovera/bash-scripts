#!/bin/bash
set -e

TODO_SH_DIR="$HOME/.todo-sh"
CURRENT_PROJECT_FILE="$TODO_SH_DIR/current_project"
DB_FILE=".todo.db"

function init_dirs() {
    mkdir -p "$TODO_SH_DIR"
}

function detect_project() {
    if [[ -f "$CURRENT_PROJECT_FILE" ]] && [[ -d "$(cat "$CURRENT_PROJECT_FILE")" ]]; then
        cat "$CURRENT_PROJECT_FILE"
        return
    fi
    
    if git rev-parse --show-toplevel 2>/dev/null; then
        return
    fi
    
    local dir="$(pwd)"
    while [[ "$dir" != "/" ]]; do
        if [[ -f "$dir/.todo-project" ]]; then
            echo "$dir"
            return
        fi
        dir="$(dirname "$dir")"
    done
    
    echo "$(pwd)"
}

function get_db_path() {
    local project_dir="$1"
    echo "$project_dir/$DB_FILE"
}

function run_migrations() {
    local db_path="$1"
    
    sqlite3 "$db_path" "
        CREATE TABLE IF NOT EXISTS migrations (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            applied_at DATETIME DEFAULT CURRENT_TIMESTAMP
        );
    "
    
    local table_exists=$(sqlite3 "$db_path" "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='tasks';")
    
    if [[ "$table_exists" == "0" ]]; then
        sqlite3 "$db_path" "
            CREATE TABLE IF NOT EXISTS tasks (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                description TEXT,
                status TEXT CHECK(status IN ('todo', 'in-progress', 'done')) DEFAULT 'todo',
                priority INTEGER DEFAULT 2,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
            );
        "
        
        sqlite3 "$db_path" "INSERT INTO migrations (name) VALUES ('initial_schema');"
    fi
}

function create_todo_script() {
    local script_path="$1"
    
    cat <<'SCRIPT_EOF' > "$script_path"
#!/bin/bash

TODO_SH_DIR="$HOME/.todo-sh"
CURRENT_PROJECT_FILE="$TODO_SH_DIR/current_project"
DB_FILE=".todo.db"

function detect_project() {
    if [[ -f "$CURRENT_PROJECT_FILE" ]] && [[ -d "$(cat "$CURRENT_PROJECT_FILE")" ]]; then
        cat "$CURRENT_PROJECT_FILE"
        return
    fi
    
    if git rev-parse --show-toplevel 2>/dev/null; then
        return
    fi
    
    local dir="$(pwd)"
    while [[ "$dir" != "/" ]]; do
        if [[ -f "$dir/.todo-project" ]]; then
            echo "$dir"
            return
        fi
        dir="$(dirname "$dir")"
    done
    
    echo "$(pwd)"
}

function get_db_path() {
    local project_dir="$1"
    echo "$project_dir/$DB_FILE"
}

function show_help() {
    echo "Usage: todo <command> [args]"
    echo ""
    echo "Task Commands:"
    echo "  add \"title\" [\"desc\"] [--pri 1-3]      Add a task"
    echo "  list [--all|--done]                   List pending tasks"
    echo "  get <id>                              Get task by ID"
    echo "  start|done <id>                       Change task status"
    echo "  update <id> --title \"...\" --desc \"...\" --pri N   Update task"
    echo "  delete <id>                           Delete task"
    echo ""
    echo "Project Commands:"
    echo "  projects list                         List projects with .todo.db"
    echo "  projects switch <path>                Switch to project by path"
    echo "  projects current                      Show current project"
    echo ""
}

case "$1" in
    add)
        TITLE="$2"
        DESC="${3:-}"
        PRI=2
        
        shift 2
        [[ -n "$1" ]] && shift
        [[ -n "$1" ]] && shift
        
        while [[ "$#" -gt 0 ]]; do
            case $1 in
                --pri) PRI="$2"; shift ;;
            esac
            shift
        done
        
        local project="$(detect_project)"
        local db_path="$(get_db_path "$project")"
        local uuid=$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null || date +%s%N)
        
        sqlite3 "$db_path" "INSERT INTO tasks (id, title, description, priority) VALUES ('$uuid', '$TITLE', '$DESC', $PRI);"
        echo "Task added: $uuid"
        ;;
        
    list)
        local project="$(detect_project)"
        local db_path="$(get_db_path "$project")"
        
        WHERE="WHERE status != 'done'"
        [[ "$2" == "--all" ]] && WHERE=""
        [[ "$2" == "--done" ]] && WHERE="WHERE status = 'done'"
        
        sqlite3 -column -header "$db_path" \
            "SELECT id, priority as PRI, printf('[%s]', status) as STATUS, title as TITLE, description as DESC FROM tasks $WHERE ORDER BY priority ASC, created_at DESC;"
        ;;
        
    get)
        if [[ -z "$2" ]]; then echo "Error: ID required"; exit 1; fi
        local project="$(detect_project)"
        local db_path="$(get_db_path "$project")"
        sqlite3 -column -header "$db_path" "SELECT * FROM tasks WHERE id='$2';"
        ;;
        
    start|done)
        local ACTION="in-progress"
        [[ "$1" == "done" ]] && ACTION="done"
        
        if [[ -z "$2" ]]; then echo "Error: ID required"; exit 1; fi
        
        local project="$(detect_project)"
        local db_path="$(get_db_path "$project")"
        sqlite3 "$db_path" "UPDATE tasks SET status='$ACTION', updated_at=CURRENT_TIMESTAMP WHERE id='$2';"
        echo "Task $2 -> $ACTION"
        ;;
        
    update)
        if [[ -z "$2" ]]; then echo "Error: ID required"; exit 1; fi
        local id="$2"
        shift 2
        
        local updates=""
        while [[ "$#" -gt 0 ]]; do
            case $1 in
                --title)
                    updates="${updates}title='$2', "
                    shift ;;
                --desc|--description)
                    updates="${updates}description='$2', "
                    shift ;;
                --pri|--priority)
                    updates="${updates}priority=$2, "
                    shift ;;
                --status)
                    updates="${updates}status='$2', "
                    shift ;;
            esac
            shift
        done
        
        updates="${updates}updated_at=CURRENT_TIMESTAMP"
        
        local project="$(detect_project)"
        local db_path="$(get_db_path "$project")"
        sqlite3 "$db_path" "UPDATE tasks SET $updates WHERE id='$id';"
        echo "Task $id updated"
        ;;
        
    delete)
        if [[ -z "$2" ]]; then echo "Error: ID required"; exit 1; fi
        local project="$(detect_project)"
        local db_path="$(get_db_path "$project")"
        sqlite3 "$db_path" "DELETE FROM tasks WHERE id='$2';"
        echo "Task deleted"
        ;;
        
    projects)
        shift
        case "$1" in
            list)
                echo "Projects with .todo.db:"
                find ~ -name ".todo.db" -type f 2>/dev/null | head -20
                ;;
            current)
                detect_project
                ;;
            switch)
                if [[ -z "$2" ]]; then echo "Error: path required"; exit 1; fi
                if [[ -d "$2" ]]; then
                    echo "$(realpath "$2")" > "$CURRENT_PROJECT_FILE"
                    echo "Switched to: $2"
                else
                    echo "Directory not found: $2"
                    exit 1
                fi
                ;;
        esac
        ;;
        
    help|--help|-h|"")
        show_help
        ;;
        
    *)
        echo "Unknown command: $1"
        show_help
        exit 1
        ;;
esac
SCRIPT_EOF

    chmod +x "$script_path"
}

function install_alias() {
    local script_path="$1"
    local alias_line="alias todo='$script_path'"
    
    if grep -q "alias todo=" "$HOME/.bashrc" 2>/dev/null; then
        sed -i "s|alias todo=.*|$alias_line|" "$HOME/.bashrc"
    else
        echo "" >> "$HOME/.bashrc"
        echo "$alias_line" >> "$HOME/.bashrc"
    fi
    
    echo "Alias installed to ~/.bashrc"
}

function main() {
    init_dirs
    
    local project_dir="$(detect_project)"
    local db_path="$(get_db_path "$project_dir")"
    run_migrations "$db_path"
    
    local todo_sh_path="$TODO_SH_DIR/todo.sh"
    create_todo_script "$todo_sh_path"
    
    if [[ "$1" == "--install-global" ]]; then
        install_alias "$todo_sh_path"
    fi
    
    echo "Initialized: $db_path"
    echo "Run 'todo help' for commands"
}

main "$@"
