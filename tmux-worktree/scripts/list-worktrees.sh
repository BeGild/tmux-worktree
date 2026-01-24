#!/bin/bash
set -euo pipefail

# Check if we're in a git repo
if ! git rev-parse --git-dir > /dev/null 2>&1; then
  echo "Error: Not in a git repository" >&2
  exit 1
fi

# Print header
printf "%-30s %-20s %-5s %s\n" "Branch" "Worktree" "Changes" "Result"
printf "%-30s %-20s %-5s %s\n" "-------" "-------" "------" "------"

WT_PATH=""
BRANCH=""

git worktree list --porcelain | while read -r line; do
  if [[ "$line" == worktree* ]]; then
    WT_PATH="${line#worktree }"
  elif [[ "$line" == branch* ]]; then
    # Fix #1: Correctly parse branch name from all formats
    BRANCH="${line#branch }"
    # Remove refs/heads/ prefix if present
    BRANCH="${BRANCH#refs/heads/}"
  elif [[ "$line" == "" ]] && [ -n "$WT_PATH" ]; then
    # Empty line = end of worktree block
    if [ -d "$WT_PATH" ]; then
      # Fix #2: Use subshell to avoid side effects on working directory
      (
        cd "$WT_PATH" 2>/dev/null || exit 0
        STATUS=$(git status --short 2>/dev/null | wc -l)
        RESULT_FILE="RESULT.md"
        if [ -f "$RESULT_FILE" ]; then
          # Fix #4: Use printf for safe handling of special characters
          FIRST_LINE=$(head -1 "$RESULT_FILE" | cut -c1-50)
          RESULT="✓ $(printf '%s' "$FIRST_LINE")"
        else
          RESULT="-"
        fi
        WT_SHORT=$(basename "$WT_PATH")
        # Fix #3: Show "(detached)" for worktrees without branch
        DISPLAY_BRANCH="${BRANCH:-}"
        if [ -z "$DISPLAY_BRANCH" ]; then
          DISPLAY_BRANCH="(detached)"
        fi
        printf "%-30s %-20s %-5s %s\n" "$DISPLAY_BRANCH" "$WT_SHORT" "$STATUS" "$RESULT"
      )
    fi
    WT_PATH=""
    BRANCH=""
  fi
done
