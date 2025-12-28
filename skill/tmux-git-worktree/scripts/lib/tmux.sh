#!/bin/bash
# tmux.sh - Tmux operations

tmux_inside() {
    [[ -n "${TMUX:-}" ]]
}

tmux_capture_current_pane() {
    if ! tmux_inside; then
        echo "Not inside tmux" >&2
        return 1
    fi
    tmux display-message -p '#{pane_id}'
}

tmux_create_hidden_window() {
    local temp_window="tm-task-$$"
    tmux new-window -d -n "$temp_window" -P -F '#{window_id}'
}

tmux_get_pane_from_window() {
    local window_id="$1"
    tmux display-message -t "${window_id}.0" -p '#{pane_id}'
}

tmux_swap_panes() {
    local source="$1"
    local target="$2"
    tmux swap-pane -s "$source" -t "$target"
}

tmux_kill_window() {
    local window_id="$1"
    tmux kill-window -t "$window_id" 2>/dev/null || true
}

tmux_list_hidden_windows() {
    local session
    session=$(tmux display-message -p '#{session_name}')
    tmux list-windows -t "$session" -F '#{window_id} #{window_name} #{window_visible}' | \
        awk '$3 == "0" && $2 ~ /^tm-task-/ {print $1 " " $2}'
}

tmux_send_command() {
    local pane="$1"
    local cmd="$2"
    tmux send-keys -t "$pane" "$cmd" Enter
}
