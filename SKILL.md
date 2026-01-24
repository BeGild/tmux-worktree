---
name: tmux-worktree
description: Creates isolated git worktree development environments with tmux sessions and AI tool integration. Use when starting new features, bug fixes, or experiments that need isolated git context and AI assistance. Automatically manages branch naming, creates dedicated tmux windows, and captures AI results.

metadata:
  author: ekko.bao
  version: "1.0.0"

compatibility: Requires git, tmux, and a configured AI tool (claude, cursor, aider, etc.)
---

## Overview

This skill creates isolated development environments for AI-assisted tasks. Each task gets:
- A fresh git worktree with a uniquely named branch
- A dedicated tmux window with your AI tool pre-loaded
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
3. **AI tool configured** - Set up in `~/.config/tmux-worktree/config.yaml`
4. **Config file exists** - Create from template if missing

## Configuration

Config location: `~/.config/tmux-worktree/config.yaml`

If missing, create from the template:
```bash
mkdir -p ~/.config/tmux-worktree
cp [skill-path]/assets/config-template.yaml ~/.config/tmux-worktree/config.yaml
```

Key settings:
- `ai_command` - The AI tool to launch (use `{prompt}` placeholder)
- `worktree_dir` - Where worktrees are created
- `branch_prefix` - Branch name prefix

## Workflow

### 1. Create a New Worktree Session

When the user wants to start a new task:

**Step-by-step:**

1. Generate a task slug from the user's description
2. Run `scripts/create-worktree.sh "<task-name>"`
3. Parse output for `WORKTREE_PATH` and `BRANCH_NAME`
4. Run `scripts/setup-tmux.sh "<worktree-path>" "<task-name>" "<prompt>"`
5. Inform the user the environment is ready

**Example:**
```bash
# Create the worktree
./tmux-worktree/scripts/create-worktree.sh "add OAuth2 login"
# Output: WORKTREE_PATH=.worktrees/add-oauth2-login
#         BRANCH_NAME=feature/add-oauth2-login

# Setup tmux with AI
./tmux-worktree/scripts/setup-tmux.sh ".worktrees/add-oauth2-login" "add-oauth2-login" "Add OAuth2 login"
# Output: SESSION=worktree-session WINDOW=add-oauth2-login
```

### 2. Query Worktree Status

When the user asks about active worktrees:

Run `scripts/list-worktrees.sh` and display the output.

### 3. View AI Results

When the user asks about results from a specific task:

1. Navigate to the worktree directory
2. Read `RESULT.md` if it exists
3. Summarize the contents

### 4. Cleanup Completed Worktrees

When the user wants to clean up:

Run `scripts/cleanup.sh` - interactively prompts for each candidate.

## Branch Naming Strategy

- Base: `feature/<task-slug>`
- If exists: `feature/<task-slug>-2`, `-3`, etc.

## AI Prompt Format

Prompts are automatically appended with result suffix from config.

## Error Handling

- Not in git repo → Clear error message
- Worktree path exists → Uses timestamp suffix
- Tmux not running → Creates session automatically

## See Also

- [references/CONFIG.md](references/CONFIG.md) - Configuration details
- [references/EXAMPLES.md](references/EXAMPLES.md) - Usage examples
