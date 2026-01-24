#!/bin/bash
set -e

TASK_NAME="$1"
BASE_DIR="${2:-.worktrees}"

# Validate inputs
if [ -z "$TASK_NAME" ]; then
  echo "Error: Task name is required" >&2
  exit 1
fi

# Check if we're in a git repo
if ! git rev-parse --git-dir > /dev/null 2>&1; then
  echo "Error: Not in a git repository" >&2
  exit 1
fi

# Generate slug from task name
SLUG=$(echo "$TASK_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-')
BASE_BRANCH="feature/$SLUG"

# Get existing branches
EXISTING=$(git branch 2>/dev/null | sed 's/^[* ] //')

# Find unique branch name
if echo "$EXISTING" | grep -q "^$BASE_BRANCH$"; then
  # Extract existing numbers
  NUMS=$(echo "$EXISTING" | grep -E "^${BASE_BRANCH}-[0-9]+$" | sed "s/^${BASE_BRANCH}-//")
  if [ -n "$NUMS" ]; then
    MAX=$(echo "$NUMS" | sort -n | tail -1)
    BRANCH_NAME="${BASE_BRANCH}-$((MAX + 1))"
  else
    BRANCH_NAME="${BASE_BRANCH}-2"
  fi
else
  BRANCH_NAME="$BASE_BRANCH"
fi

# Create worktree
WORKTREE_PATH="${BASE_DIR}/${SLUG}"

# Check if worktree path already exists
if [ -d "$WORKTREE_PATH" ]; then
  # Add timestamp to make unique
  TIMESTAMP=$(date +%Y%m%d-%H%M%S)
  WORKTREE_PATH="${BASE_DIR}/${SLUG}-${TIMESTAMP}"
fi

git worktree add "$WORKTREE_PATH" -b "$BRANCH_NAME"

# Output metadata for caller
echo "WORKTREE_PATH=$WORKTREE_PATH"
echo "BRANCH_NAME=$BRANCH_NAME"
