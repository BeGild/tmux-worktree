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

# Load config
CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/tmux-worktree/config.yaml"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "Error: Config file not found at $CONFIG_FILE" >&2
  echo "Please create it from the template" >&2
  exit 1
fi

# Parse ai_command from config
AI_COMMAND=$(grep "^ai_command:" "$CONFIG_FILE" | cut -d':' -f2- | sed 's/^[[:space:]]*//')

# Parse result_prompt_suffix (multiline)
RESULT_SUFFIX=""
while IFS= read -r line; do
  if [[ "$line" == result_prompt_suffix:* ]]; then
    continue
  elif [[ "$line" == ^[a-z_]*: ]] && [ -n "$RESULT_SUFFIX" ]; then
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

# Window name (truncate to 20 chars)
WINDOW_NAME=$(echo "$TASK_NAME" | cut -c1-20)

# Check if tmux session exists
if ! tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
  tmux new-session -d -s "$SESSION_NAME" -n "$WINDOW_NAME" -c "$WORKTREE_PATH"
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
