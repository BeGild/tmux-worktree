#!/bin/bash
# tmux.sh - Tmux operations

tmux_inside() {
    [[ -n "${TMUX:-}" ]]
}

# Get current session name
tmux_get_session() {
    tmux display-message -p '#{session_name}'
}

# Create new window with task name and switch to it
tmux_create_task_window() {
    local task_name="$1"
    local worktree_path="$2"

    # Create new window and switch to it
    local window_id
    window_id=$(tmux new-window -n "$task_name" -P -F '#{window_id}')

    # Change directory in the new window's first pane
    tmux send-keys -t "$window_id" "cd '$worktree_path'" Enter

    echo "$window_id"
}

# Kill a specific window
tmux_kill_window() {
    local window_id="$1"
    tmux kill-window -t "$window_id" 2>/dev/null || true
}

# Get window ID by name pattern
tmux_find_window_by_name() {
    local name_pattern="$1"
    local session
    session=$(tmux_get_session)
    tmux list-windows -t "$session" -F '#{window_id} #{window_name}' | \
        awk -v pattern="$name_pattern" '$2 == pattern {print $1}'
}

# Send command to a window's pane
tmux_send_command() {
    local window_id="$1"
    local cmd="$2"
    tmux send-keys -t "$window_id" "$cmd" Enter
}

# Check if a window exists
tmux_window_exists() {
    local window_id="$1"
    tmux display-message -t "$window_id" -p '#{window_id}' >/dev/null 2>&1
}
