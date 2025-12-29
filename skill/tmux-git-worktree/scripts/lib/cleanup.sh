#!/bin/bash
# cleanup.sh - Cleanup orchestration

TASK_WINDOW=""
WORKTREE_PATH=""
BRANCH_NAME=""

cleanup_setup() {
    TASK_WINDOW="$1"
    WORKTREE_PATH="$2"
    BRANCH_NAME="$3"
    trap cleanup_handler EXIT INT TERM
}

cleanup_handler() {
    local exit_code=$?

    # Always check worktree status (window may already be closed)
    echo ""
    echo "========================================="
    echo "Task completed: $BRANCH_NAME"
    echo "========================================="
    echo ""
    echo "Worktree: $WORKTREE_PATH"

    if git_worktree_has_changes "$WORKTREE_PATH"; then
        echo "Status: Uncommitted changes detected"
        echo ""
        echo "Keeping worktree and task window."
        echo "Use 'tm-recover' to clean up later."
    else
        echo "Status: No uncommitted changes"
        echo ""
        # Auto-cleanup only if no changes
        git_worktree_delete "$WORKTREE_PATH" "$BRANCH_NAME"

        # Close the task window if it still exists
        if [[ -n "$TASK_WINDOW" ]] && tmux_window_exists "$TASK_WINDOW"; then
            tmux_kill_window "$TASK_WINDOW"
        fi
    fi

    trap - EXIT INT TERM
    exit $exit_code
}

# Manual cleanup command for orphaned worktrees
cleanup_orphans() {
    local base_dir
    base_dir=$(git_worktree_get_base_dir)

    if [[ ! -d "$base_dir" ]]; then
        echo "No worktree base directory found: $base_dir"
        return 0
    fi

    echo "Checking for orphaned worktrees in: $base_dir"
    echo ""

    local cleaned=0
    for worktree in "${base_dir}"/*; do
        if [[ -d "$worktree" ]]; then
            local branch_name
            branch_name=$(basename "$worktree")

            echo "Checking: $branch_name"

            if ! git_worktree_has_changes "$worktree"; then
                echo "  -> No changes, removing..."
                git_worktree_delete "$worktree" "$branch_name"
                ((cleaned++))
            else
                echo "  -> Has changes, keeping"
            fi
        fi
    done

    echo ""
    echo "Cleaned $cleaned orphaned worktree(s)"
}
