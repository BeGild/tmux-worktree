#!/bin/bash
set -euo pipefail

# Check if we're in a git repo
if ! git rev-parse --git-dir > /dev/null 2>&1; then
  echo "Error: Not in a git repository" >&2
  exit 1
fi

# Print header
printf "%-30s %-20s %-5s %s\n" "Branch" "Worktree" "Files" "Result"
printf "%-30s %-20s %-5s %s\n" "-------" "-------" "-----" "------"

WT_PATH=""
BRANCH=""

git worktree list --porcelain | while read -r line; do
  if [[ "$line" == worktree* ]]; then
    WT_PATH="${line#worktree }"
  elif [[ "$line" == branch* ]]; then
    BRANCH="${line#branch refs/heads/}"
    if [[ "$BRANCH" == refs/heads/* ]]; then
      BRANCH="${BRANCH#refs/heads/}"
    fi
  elif [[ "$line" == "" ]] && [ -n "$WT_PATH" ]; then
    # Empty line = end of worktree block
    if [ -d "$WT_PATH" ]; then
      cd "$WT_PATH" 2>/dev/null || continue
      STATUS=$(git status --short 2>/dev/null | wc -l)
      RESULT_FILE="RESULT.md"
      if [ -f "$RESULT_FILE" ]; then
        RESULT="✓ $(head -1 "$RESULT_FILE" | cut -c1-50)"
      else
        RESULT="-"
      fi
      WT_SHORT=$(basename "$WT_PATH")
      printf "%-30s %-20s %-5s %s\n" "$BRANCH" "$WT_SHORT" "$STATUS" "$RESULT"
    fi
    WT_PATH=""
    BRANCH=""
  fi
done
