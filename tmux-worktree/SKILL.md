---
name: tmux-worktree
description: Creates isolated git worktree development environments with tmux sessions. Use when starting new features, bug fixes, or experiments that need isolated git context. Automatically manages branch naming, creates dedicated tmux windows.
---

## Overview

This skill creates isolated development environments for AI-assisted tasks. Each task gets:

- A fresh git worktree with a uniquely named branch
- A dedicated tmux window with your AI tool pre-loaded
- Interactive AI tool selection (when multiple tools configured)
- Automatic result capture via RESULT.md files

## When to Use

Use this skill when:

- Starting a new feature, bug fix, or experiment
- The user mentions "new branch", "isolated environment", "worktree"
- You need to work on multiple tasks simultaneously
- The user wants AI assistance on a specific task

## Prerequisites

1. **Git repository** - Must be run from within a git repo
2. **tmux installed** - For window/session management
3. **AI tool configured** - Run `./bin/tmux-worktree query-config` to check available tools

## Workflow

### 1. Create a New Worktree Session

When the user wants to start a new task:

**Step-by-step:**

1. Query available AI tools by running `./bin/tmux-worktree query-config`
2. **Interactive AI Selection:**
   - If only one AI tool is available, use it automatically
   - If multiple AI tools are available, use `AskUserQuestion` to let the user choose
3. Generate a task slug from the user's description
4. Run `./bin/tmux-worktree create "<task-name>"`
5. Parse output for `WORKTREE_PATH` and `BRANCH_NAME`
6. Run `./bin/mux-worktree setup "<worktree-path>" "<task-name>" "<ai-tool>" "<prompt>"`
7. Inform the user the environment is ready

**Interactive AI Selection with AskUserQuestion:**

```javascript
{
  "questions": [{
    "question": "选择AI工具用于此任务：",
    "header": "AI工具",
    "options": aiTools.map(tool => ({
      "label": tool.name,
      "description": tool.description
    })),
    "multiSelect": false
  }]
}
```

**Example:**

```bash
# Query available tools
./bin/tmux-worktree query-config
# Output: { "default_ai": "claude", "ai_tools": [...] }

# Create the worktree
./bin/tmux-worktree create "add OAuth2 login"
# Output: WORKTREE_PATH=.worktrees/add-oauth2-login
#         BRANCH_NAME=feature/add-oauth2-login

# Setup tmux with AI (claude selected interactively)
./bin/tmux-worktree setup ".worktrees/add-oauth2-login" "add-oauth2-login" "claude" "Add OAuth2 login"
# Output: SESSION=worktree-session WINDOW=add-oauth2-login AI_TOOL=claude
```

### 2. Query Worktree Status

When the user asks about active worktrees:

Run `tmux-worktree list` and display the output.

### 3. View AI Results

When the user asks about results from a specific task:

1. Navigate to the worktree directory
2. Read `RESULT.md` if it exists
3. Summarize the contents

### 4. Cleanup Completed Worktrees

When the user wants to clean up:

Run `tmux-worktree cleanup` - interactively prompts for each candidate.

## Branch Naming Strategy

- Base: `feature/<task-slug>`
- If exists: `feature/<task-slug>-2`, `-3`, etc.

## Error Handling

- Not in git repo → Clear error message
- Worktree path exists → Uses timestamp suffix
- Tmux not running → Creates session automatically
- AI tool not found → Lists available tools
- Config file missing → Automatically created from template

## See Also

- Usage examples: Run `tmux-worktree --help` for usage information
