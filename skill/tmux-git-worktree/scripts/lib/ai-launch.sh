#!/bin/bash
# ai-launch.sh - AI tool launch configuration

# Get AI launch command from environment or use defaults
# Environment variable format: TM_TASK_AI_CMD_<tool>=command
# Example: TM_TASK_AI_CMD_CLAUDE="claude --model opus"
ai_get_launch_cmd() {
    local ai_tool="$1"
    local description="$2"

    # Check for custom command via environment variable
    local env_var="TM_TASK_AI_CMD_${ai_tool^^}"
    local custom_cmd="${!env_var:-}"

    if [[ -n "$custom_cmd" ]]; then
        echo "$custom_cmd"
        return
    fi

    # Default launch commands
    case "$ai_tool" in
        claude)
            echo "claude"
            ;;
        codex)
            if [[ -n "$description" ]]; then
                echo "codex --message \"$description\""
            else
                echo "codex"
            fi
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

# Launch AI tool
ai_launch() {
    local ai_tool="$1"
    local description="$2"
    local worktree_path="$3"

    cd "$worktree_path"

    local launch_cmd
    launch_cmd=$(ai_get_launch_cmd "$ai_tool" "$description")

    log "Launching: $launch_cmd"

    # Execute the command
    eval "exec $launch_cmd"
}
