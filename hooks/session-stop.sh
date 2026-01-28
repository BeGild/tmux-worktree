#!/usr/bin/env bash
# Stop hook for tmux-worktree plugin
# Blocks stop to ensure AI generates RESULT.md before ending session

set -euo pipefail

# Get current working directory
CURRENT_DIR="$(pwd)"
CURRENT_DIR_REAL="$(cd "$CURRENT_DIR" && pwd)"

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    exit 0
fi

# Check if this is a worktree by verifying it's in the git worktree list
# This is the most reliable way to detect if we're in a worktree
WORKTREE_LIST="$(git worktree list 2>/dev/null || echo "")"

# Check if current directory is in the worktree list
IN_WORKTREE=false
while IFS= read -r line; do
    WORKTREE_PATH="${line%% *}"
    # Normalize both paths for comparison
    WORKTREE_PATH_REAL="$(cd "$WORKTREE_PATH" 2>/dev/null && pwd || echo "$WORKTREE_PATH")"

    if [ "$CURRENT_DIR_REAL" = "$WORKTREE_PATH_REAL" ] || \
       [[ "$CURRENT_DIR_REAL" == "$WORKTREE_PATH_REAL"/* ]]; then
        IN_WORKTREE=true
        break
    fi
done <<< "$WORKTREE_LIST"

if [ "$IN_WORKTREE" = false ]; then
    # Not in a worktree, allow normal stop
    exit 0
fi

# ===========================================================================
# RESULT.md Template - Modify this section to change the output format
# ===========================================================================

read -r -d '' RESULT_TEMPLATE <<'TEMPLATE'
# Task Summary

## Status
[Select one: In Progress / Completed / Blocked / Abandoned]

## Overview
[Brief description of what you were working on]

## Changes Made
[Summary of changes implemented]

## Files Modified
- [List modified files - use 'git status --short' to check]

## Commits
- [List commits made - use 'git log --oneline' to check]

## Testing
[Describe testing performed and results]

## Blockers / Issues
[If Status is Blocked, describe the issue. Otherwise, write 'None']

## Next Steps
[What needs to be done next?]

## Cleanup Recommendation
[Select one and explain:
- Ready to merge → Can be merged to main branch
- Continue working → Keep worktree for more work
- Cleanup recommended → Safe to remove worktree
- Needs review → Requires human review before cleanup]
TEMPLATE

# ===========================================================================
# Instructions for AI - Modify this section to change the behavior
# ===========================================================================

read -r -d '' INSTRUCTION <<'INSTRUCTION'
You are in a git worktree environment. Before stopping, you MUST create or update RESULT.md with a comprehensive summary of your work.

## Checklist

Before creating RESULT.md, run these commands to gather information:

1. Check git status: `git status --short`
2. Check commits: `git log --oneline -10`
3. Check branch: `git rev-parse --abbrev-ref HEAD`
4. Check diff: `git diff --stat`

## Important Notes

- Be honest about the status - if blocked, explain why
- If you made no progress, state that clearly
- The cleanup recommendation helps with worktree management
- This file will be read by other AI agents or humans reviewing the work

After creating RESULT.md, you may stop.
INSTRUCTION

# ===========================================================================
# Build the full prompt and generate JSON output
# ===========================================================================

# Combine instruction and template
FULL_PROMPT="${INSTRUCTION}

## Required RESULT.md Structure

${RESULT_TEMPLATE}"

# Escape for JSON: backslashes, quotes, newlines
ESCAPED_PROMPT=$(echo "$FULL_PROMPT" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | awk '{printf "%s\\n", $0}' | head -c -2)

# Output JSON
cat <<EOF
{
  "decision": "block",
  "reason": "${ESCAPED_PROMPT}"
}
EOF

exit 0
