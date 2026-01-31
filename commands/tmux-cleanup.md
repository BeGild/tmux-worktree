---
description: "Cleanup completed or stale worktrees. Shows current state first, then guides through interactive cleanup."
disable-model-invocation: true
---

Follow the **CLEANUP** phase from the tmux-worktree skill:

1. **Query status**: `${SKILL_ROOT}/bin/tmux-worktree list`
   - ALWAYS show current state before cleanup
2. **Review progress**: Offer to show `.worktrees/<task-name>/.tmux-worktree/progress.md` contents for tasks being removed
3. **Interactive cleanup**: `${SKILL_ROOT}/bin/tmux-worktree cleanup`
   - Guides user through prompts for each candidate worktree
4. Confirm removal was successful
