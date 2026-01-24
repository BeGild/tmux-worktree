#!/bin/bash
set -euo pipefail

WORKTREE_PATH="$1"
TASK_NAME="$2"
PROMPT="$3"

# Validate inputs
if [ -z "$WORKTREE_PATH" ] || [ -z "$TASK_NAME" ] || [ -z "$PROMPT" ]; then
  echo "Usage: $0 <worktree-path> <task-name> <prompt>" >&2
  exit 1
fi

# Check if tmux is installed
command -v tmux >/dev/null 2>&1 || { echo "Error: tmux not installed" >&2; exit 1; }

# Validate worktree path exists
[ -d "$WORKTREE_PATH" ] || { echo "Error: worktree path not found: $WORKTREE_PATH" >&2; exit 1; }

# Load config
CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/tmux-worktree/config.yaml"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "Error: Config file not found at $CONFIG_FILE" >&2
  echo "Please create it from the template" >&2
  exit 1
fi

# Parse ai_command from config
AI_COMMAND=$(grep "^ai_command:" "$CONFIG_FILE" | cut -d':' -f2- | sed 's/^[[:space:]]*//')

# Validate ai_command is present
[ -n "$AI_COMMAND" ] || { echo "Error: ai_command not found in config file" >&2; exit 1; }

# Parse result_prompt_suffix (multiline)
RESULT_SUFFIX=""
while IFS= read -r line; do
  if [[ "$line" == result_prompt_suffix:* ]]; then
    continue
  elif [[ "$line" =~ ^[a-z_]+: ]] && [ -n "$RESULT_SUFFIX" ]; then
    break
  elif [ -n "$line" ] || [ -n "$RESULT_SUFFIX" ]; then
    RESULT_SUFFIX="$RESULT_SUFFIX$line"$'\n'
  fi
done < "$CONFIG_FILE"

# Build full prompt with result suffix
FULL_PROMPT="$PROMPT"$'\n\n'"$RESULT_SUFFIX"

# Get tmux session name
if [ -n "$TMUX" ]; then
  SESSION_NAME=$(tmux display-message -p '#S')
else
  SESSION_NAME="worktree-session"
fi

# Window name (sanitize and truncate to 20 chars)
WINDOW_NAME=$(echo "$TASK_NAME" | tr -cs 'a-zA-Z0-9-' '-' | cut -c1-20)

# Create session or window (avoid race condition)
if tmux new-session -d -s "$SESSION_NAME" -n "$WINDOW_NAME" -c "$WORKTREE_PATH" 2>/dev/null; then
  : # Session created successfully
else
  tmux new-window -t "$SESSION_NAME" -n "$WINDOW_NAME" -c "$WORKTREE_PATH"
fi

# Construct AI command with prompt (escape single quotes in prompt)
ESCAPED_PROMPT=$(echo "$FULL_PROMPT" | sed "s/'/'\\\\''/g")
AI_CMD=$(echo "$AI_COMMAND" | sed "s/{prompt}/'${ESCAPED_PROMPT}'/")

# Send command to the window
tmux send-keys -t "$SESSION_NAME:$WINDOW_NAME" "$AI_CMD" C-m

# Output metadata for caller
echo "SESSION=$SESSION_NAME"
echo "WINDOW=$WINDOW_NAME"
