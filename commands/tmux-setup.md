---
description: "Setup a new tmux worktree environment with AI. Creates isolated git worktree with dedicated tmux window and AI tool. Use when starting new features, bug fixes, or experiments."
disable-model-invocation: true
---

Follow the **CREATE** phase from the tmux-worktree skill:

1. Verify `.gitignore` contains `.worktrees/` and `.tmux-worktree/`
2. Query available AI tools: `${SKILL_ROOT}/bin/tmux-worktree query-config`
3. If multiple AI tools exist, use `AskUserQuestion` to let user choose
4. Generate a task slug from the user's task description
5. Run: `${SKILL_ROOT}/bin/tmux-worktree create "<task-name>"`
6. Parse output for `WORKTREE_PATH`, `BRANCH_NAME`, `PARENT_BRANCH`
7. Structure the prompt using the Prompt Template from SKILL.md
8. Run: `${SKILL_ROOT}/bin/tmux-worktree setup "<worktree-path>" "<task-name>" [ai-tool] "<structured-prompt>"`
9. Inform user the environment is ready in tmux
