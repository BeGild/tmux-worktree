#!/bin/bash
set -euo pipefail

# Check if we're in a git repo
if ! git rev-parse --git-dir > /dev/null 2>&1; then
  echo "Error: Not in a git repository" >&2
  exit 1
fi

# Get main branch - try common alternatives
MAIN_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@refs/remotes/origin/@@')
if [ -z "$MAIN_BRANCH" ]; then
  # Try to detect main branch from common alternatives
  if git show-ref --verify --quiet refs/heads/main 2>/dev/null; then
    MAIN_BRANCH="main"
  elif git show-ref --verify --quiet refs/heads/master 2>/dev/null; then
    MAIN_BRANCH="master"
  else
    MAIN_BRANCH="main"
  fi
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
    # Fix #1: Correctly parse branch name from all formats
    BRANCH="${line#branch }"
    # Remove refs/heads/ prefix if present
    BRANCH="${BRANCH#refs/heads/}"
  elif [[ "$line" == "" ]] && [ -n "$WT_PATH" ]; then
    # Empty line = end of worktree block
    # Skip main worktree
    if [ "$WT_PATH" != "$MAIN_Toplevel" ]; then
      # Fix #2: Use subshell to avoid side effects on working directory
      (
        cd "$WT_PATH" 2>/dev/null || exit 0

        # Fix #8: Ensure git commands run from the worktree location
        MAIN_TOPLEVEL=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0

        # Fix #3: Show "(detached)" for worktrees without branch
        DISPLAY_BRANCH="${BRANCH:-}"
        if [ -z "$DISPLAY_BRANCH" ]; then
          DISPLAY_BRANCH="(detached)"
        fi

        # Check if branch is merged to main (skip for detached)
        IS_MERGED=0
        if [ -n "$BRANCH" ] && git show-ref --verify --quiet "refs/heads/$BRANCH" 2>/dev/null; then
          # Fix #5: Use word matching for grep to avoid substring matches
          IS_MERGED=$(git branch --merged "$MAIN_BRANCH" 2>/dev/null | grep -cw "$BRANCH" || echo "0")
        fi

        # Fix #6: Check for commits unique to this branch
        HAS_COMMITS=0
        if [ -n "$BRANCH" ]; then
          # Count commits not in main branch
          HAS_COMMITS=$(git log "$MAIN_BRANCH..$BRANCH" --oneline 2>/dev/null | wc -l) || echo "0"
        fi

        # Candidate if merged or no unique commits
        if [ "$IS_MERGED" -gt 0 ] || [ "$HAS_COMMITS" -eq 0 ]; then
          REASON=""
          if [ "$IS_MERGED" -gt 0 ]; then
            REASON="(merged to $MAIN_BRANCH)"
          else
            REASON="(no unique commits)"
          fi

          echo "$WT_PATH|$DISPLAY_BRANCH|$REASON"
        fi
      )
    fi
    WT_PATH=""
    BRANCH=""
  fi
done | while IFS='|' read -r WT_PATH BRANCH REASON; do
  echo "Remove $BRANCH $REASON?"
  echo "  Path: $WT_PATH"
  read -r -p "[y/N] " ANSWER
  if [ "$ANSWER" = "y" ] || [ "$ANSWER" = "Y" ]; then
    # Fix #7: Use git worktree remove --force instead of rm -rf for safer removal
    git worktree remove --force "$WT_PATH" 2>/dev/null || echo "Warning: Could not remove worktree at $WT_PATH"
    # Skip branch deletion for detached worktrees
    if [ "$BRANCH" != "(detached)" ] && git show-ref --verify --quiet "refs/heads/$BRANCH" 2>/dev/null; then
      git branch -d "$BRANCH" 2>/dev/null || echo "Warning: Could not delete branch $BRANCH"
    fi
    echo "✓ Removed: $BRANCH"
  else
    echo "Skipped: $BRANCH"
  fi
  echo ""
done
