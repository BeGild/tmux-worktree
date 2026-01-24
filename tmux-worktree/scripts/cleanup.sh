#!/bin/bash
set -euo pipefail

# Check if we're in a git repo
if ! git rev-parse --git-dir > /dev/null 2>&1; then
  echo "Error: Not in a git repository" >&2
  exit 1
fi

# Get main branch
MAIN_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@refs/remotes/origin/@@')
if [ -z "$MAIN_BRANCH" ]; then
  MAIN_BRANCH="main"
fi

# Find candidates for cleanup
MAIN_Toplevel=$(git rev-parse --show-toplevel)

CANDIDATES=()
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
    # Skip main worktree
    if [ "$WT_PATH" != "$MAIN_Toplevel" ]; then
      cd "$WT_PATH" 2>/dev/null || continue

      # Check if branch is merged to main
      IS_MERGED=0
      if git show-ref --verify --quiet "refs/heads/$BRANCH" 2>/dev/null; then
        IS_MERGED=$(git branch --merged "$MAIN_BRANCH" 2>/dev/null | grep -c "$BRANCH" || echo "0")
      fi

      # Check for commits
      HAS_COMMITS=$(git log --oneline 2>/dev/null | wc -l)

      # Candidate if merged or no commits
      if [ "$IS_MERGED" -gt 0 ] || [ "$HAS_COMMITS" -eq 0 ]; then
        REASON=""
        if [ "$IS_MERGED" -gt 0 ]; then
          REASON="(merged to $MAIN_BRANCH)"
        else
          REASON="(no commits)"
        fi

        echo "$WT_PATH|$BRANCH|$REASON"
      fi
    fi
    WT_PATH=""
    BRANCH=""
  fi
done | while IFS='|' read -r WT_PATH BRANCH REASON; do
  echo "Remove $BRANCH $REASON?"
  echo "  Path: $WT_PATH"
  read -r -p "[y/N] " ANSWER
  if [ "$ANSWER" = "y" ] || [ "$ANSWER" = "Y" ]; then
    git worktree remove "$WT_PATH" 2>/dev/null || rm -rf "$WT_PATH"
    if git show-ref --verify --quiet "refs/heads/$BRANCH" 2>/dev/null; then
      git branch -d "$BRANCH" 2>/dev/null || echo "Warning: Could not delete branch $BRANCH"
    fi
    echo "✓ Removed: $BRANCH"
  else
    echo "Skipped: $BRANCH"
  fi
  echo ""
done
