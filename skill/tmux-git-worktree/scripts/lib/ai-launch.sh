#!/bin/bash
# ai-launch.sh - AI tool launch configuration

# Get AI launch command from environment or use defaults
ai_get_launch_cmd() {
    local ai_tool="$1"

    # Check for custom command via environment variable
    local env_var="TM_TASK_AI_CMD_${ai_tool^^}"
    local custom_cmd="${!env_var:-}"

    if [[ -n "$custom_cmd" ]]; then
        echo "$custom_cmd"
        return
    fi

    # Default launch commands (without prompt argument)
    case "$ai_tool" in
        claude)
            echo "claude"
            ;;
        codex)
            echo "codex"
            ;;
        none|"")
            echo "bash --login"
            ;;
        *)
            # Custom command - pass through as-is
            echo "$ai_tool"
            ;;
    esac
}

# Launch AI tool with initial prompt and monitor window
ai_launch() {
    local ai_tool="$1"
    local initial_prompt="$2"
    local worktree_path="$3"
    local task_window="$4"

    cd "$worktree_path"

    # Get the base AI command
    local base_cmd
    base_cmd=$(ai_get_launch_cmd "$ai_tool")

    # Build command with prompt
    local full_cmd
    if [[ -n "$initial_prompt" ]]; then
        # Write prompt to temporary file (will be cleaned up when worktree is deleted)
        local prompt_file="${worktree_path}/.tm-task-prompt.tmp"
        echo "$initial_prompt" > "$prompt_file"

        # Use cat to pipe the prompt to the AI tool
        full_cmd="cat '$prompt_file' | $base_cmd"
    else
        full_cmd="$base_cmd"
    fi

    log "Launching: $full_cmd"
    log "Monitoring window: $task_window"

    # Send the command to the task window's pane
    tmux_send_command "$task_window" "$full_cmd"

    # Monitor window - exit when window is closed by user
    local check_count=0
    while true; do
        sleep 1
        ((check_count++))

        # Check if window still exists
        if ! tmux_window_exists "$task_window"; then
            log "Window $task_window closed by user (after ${check_count}s), exiting..."
            exit 0
        fi

        # Debug logging every 30 seconds
        if [[ $((check_count % 30)) -eq 0 ]]; then
            log "Window still open (${check_count}s elapsed)"
        fi
    done
}
