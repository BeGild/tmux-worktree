#!/usr/bin/env python3
"""
Stop hook for tmux-worktree plugin
Blocks stop to ensure AI generates RESULT.md before ending session

Best practices from:
https://gist.github.com/alexfazio/653c5164d726987569ee8229a19f451f
"""

import os
import sys
import json

def main():
    try:
        # Get current working directory
        current_dir = os.getcwd()

        # Check if we're in a git repository
        git_dir = os.path.join(current_dir, ".git")
        if not os.path.exists(git_dir):
            sys.exit(0)

        # Check if this is a worktree (not the main repo)
        # In a worktree, .git is a file, not a directory
        if os.path.isfile(git_dir):
            # .git is a file → this is a worktree
            pass
        elif os.path.isdir(git_dir):
            # .git is a directory → main repo, not a worktree
            sys.exit(0)
        else:
            # No .git found
            sys.exit(0)

        # ===========================================================================
        # RESULT.md Template - Modify this section to change the output format
        # ===========================================================================

        RESULT_TEMPLATE = """# Task Summary

## Status
[Select one: In Progress / Completed / Blocked / Abandoned]

## Overview
[Brief description of what you were working on]

## Changes Made
[Summary of changes implemented]

## Files Modified
- [List modified files - use `git status --short` to check]

## Commits
- [List commits made - use `git log --oneline` to check]

## Testing
[Describe testing performed and results]

## Blockers / Issues
[If Status is Blocked, describe the issue. Otherwise, write `None`]

## Next Steps
[What needs to be done next?]

## Cleanup Recommendation
[Select one and explain:
- Ready to merge → Can be merged to main branch
- Continue working → Keep worktree for more work
- Cleanup recommended → Safe to remove worktree
- Needs review → Requires human review before cleanup]"""

        # ===========================================================================
        # Instructions for AI - Modify this section to change the behavior
        # ===========================================================================

        INSTRUCTION = """You are in a git worktree environment. Before stopping, you MUST create or update RESULT.md with a comprehensive summary of your work.

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

After creating RESULT.md, you may stop."""

        # ===========================================================================
        # Build the full prompt and generate JSON output
        # ===========================================================================

        # Combine instruction and template
        full_prompt = f"""{INSTRUCTION}

## Required RESULT.md Structure

{RESULT_TEMPLATE}"""

        # Output JSON - proper format for Stop hook
        output = {
            "decision": "block",
            "reason": full_prompt
        }

        # Print to stdout
        print(json.dumps(output, ensure_ascii=False, indent=2))
        sys.exit(0)

    except Exception as e:
        # Log error to stderr and exit gracefully
        print(f"[ERROR] Hook failed: {type(e).__name__}: {e}", file=sys.stderr)
        sys.exit(0)

if __name__ == "__main__":
    main()
