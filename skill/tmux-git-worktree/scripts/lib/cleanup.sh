#!/bin/bash
# cleanup.sh - Cleanup orchestration

ORIGIN_PANE=""
TASK_PANE=""
HIDDEN_WINDOW=""
WORKTREE_PATH=""
BRANCH_NAME=""
ORIGINAL_PATH=""

cleanup_setup() {
    ORIGIN_PANE="$1"
    TASK_PANE="$2"
    HIDDEN_WINDOW="$3"
    WORKTREE_PATH="$4"
    BRANCH_NAME="$5"
    ORIGINAL_PATH="$6"
    trap cleanup_handler EXIT INT TERM
}

cleanup_handler() {
    local exit_code=$?

    if [[ -n "$ORIGIN_PANE" && -n "$TASK_PANE" ]]; then
        tmux swap-pane -s "$ORIGIN_PANE" -t "$TASK_PANE" 2>/dev/null || true
    fi

    if git_worktree_has_changes "$WORKTREE_PATH"; then
        echo "WARNING: Uncommitted changes!"
        echo "Worktree preserved: $WORKTREE_PATH"
    else
        git_worktree_delete "$WORKTREE_PATH" "$BRANCH_NAME"
    fi

    if [[ -n "$HIDDEN_WINDOW" ]]; then
        tmux_kill_window "$HIDDEN_WINDOW"
    fi

    trap - EXIT INT TERM
    exit $exit_code
}

cleanup_orphans() {
    local base_dir
    base_dir=$(git_worktree_get_base_dir)

    if [[ ! -d "$base_dir" ]]; then
        return 0
    fi

    for worktree in "${base_dir}"/*; do
        if [[ -d "$worktree" ]]; then
            local branch_name
            branch_name=$(basename "$worktree")

            if ! git_worktree_has_changes "$worktree"; then
                git_worktree_delete "$worktree" "$branch_name"
            fi
        fi
    done
}
