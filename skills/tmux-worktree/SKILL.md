---
name: tmux-worktree
description: Creates isolated git worktree development environments with tmux sessions. Use when starting new features, bug fixes, or experiments that need isolated git context. Automatically manages branch naming, creates dedicated tmux windows.
---

## Skill Root Location

**SKILL_ROOT** = Directory containing this SKILL.md file (NOT `pwd`)

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
3. **AI tool configured** - Run `${SKILL_ROOT}/bin/tmux-worktree query-config` to check available tools

### Project Setup (First Time Only)

**Required .gitignore entries:**

Before creating your first worktree, ensure your `.gitignore` includes:

```gitignore
# Worktrees
.worktrees/

# AI task results
RESULT.md
```

**Verify with:** `cat .gitignore | grep -E "worktrees|RESULT.md"`

If missing, add these entries to prevent worktree directories and result files from being committed.

## Worktree Task Lifecycle

> **Task Checklist** - Track progress with TodoWrite:
>
> - [ ] **CREATE** - Set up new worktree environment
> - [ ] **WORK** - AI-assisted development in isolated environment
> - [ ] **CLEANUP** - Query status, review results, remove worktree

### Phase 1: CREATE

Start a new isolated development environment.

**When to use:** User wants to start a new feature, bug fix, or experiment.

**Step-by-step:**

0. **Pre-check**: Verify `.gitignore` is configured

   ```bash
   cat .gitignore | grep -E "worktrees|RESULT.md"
   # If missing, add: .worktrees/ and RESULT.md
   ```

1. Query available AI tools: `${SKILL_ROOT}/bin/tmux-worktree query-config`
2. **Interactive AI Selection:**
   - If only one AI tool → use it automatically
   - If multiple AI tools → use `AskUserQuestion` to let user choose
3. Generate a task slug from user's description
4. Run: `${SKILL_ROOT}/bin/tmux-worktree create "<task-name>"`
5. Parse output for `WORKTREE_PATH` and `BRANCH_NAME`
6. Run: `${SKILL_ROOT}/bin/tmux-worktree setup "<worktree-path>" "<task-name>" "<ai-tool>" "<prompt>"`
7. Inform user the environment is ready

**AI Responsibility:**

- Verify `.gitignore` configuration
- Guide AI tool selection when multiple options exist
- Confirm environment is ready before proceeding

### Phase 2: WORK

AI-assisted development happens in the isolated worktree.

**Key behaviors:**

- All work stays in the worktree directory
- Branch is isolated from main/master
- AI tool runs in dedicated tmux window
- RESULT.md captures final outcomes

**Transition trigger:** User signals completion or asks to clean up

### Phase 3: CLEANUP

Remove completed worktrees after preserving results.

**When to use:** Task is complete or user wants to clean up.

**Step-by-step:**

1. **Query status:** `${SKILL_ROOT}/bin/tmux-worktree list`
   - Always show current state before cleanup
2. **Review results:** `cat .worktrees/<task-name>/RESULT.md` (if exists)
   - Offer to show RESULT.md contents for tasks being removed
3. **Interactive cleanup:** `${SKILL_ROOT}/bin/tmux-worktree cleanup`
   - Guides user through prompts for each candidate

**AI Responsibility:**

- ALWAYS run `list` before cleanup to show current state
- Offer to display RESULT.md before removing worktrees
- Guide user through interactive cleanup prompts
- Confirm removal was successful

**DO NOT SKIP:** Always complete cleanup after tasks finish to prevent worktree accumulation.

## Branch Naming Strategy

- Base: `feature/<task-slug>`
- If exists: `feature/<task-slug>-2`, `-3`, etc.

## Error Handling

- Not in git repo → Clear error message
- Worktree path exists → Uses timestamp suffix
- Tmux not running → Creates session automatically
- AI tool not found → Lists available tools
- Config file missing → Automatically created from template

## Quick Reference

### Commands

```bash
# Query available AI tools
${SKILL_ROOT}/bin/tmux-worktree query-config
# Output: { "default_ai": "...", "ai_tools": {...} }

# Create a new worktree
${SKILL_ROOT}/bin/tmux-worktree create "<task-name>"
# Output: WORKTREE_PATH=.worktrees/<task-slug>
#         BRANCH_NAME=feature/<task-slug>

# Setup tmux session with AI
${SKILL_ROOT}/bin/tmux-worktree setup "<worktree-path>" "<task-name>" [ai-tool] "<prompt>"
# Output: SESSION=worktree-session WINDOW=<task-slug> AI_TOOL=<tool>

# List active worktrees
${SKILL_ROOT}/bin/tmux-worktree list

# Cleanup completed worktrees (interactive)
${SKILL_ROOT}/bin/tmux-worktree cleanup
```

### Interactive AI Selection Format

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

### Example Session

```bash
# 1. Create the worktree
${SKILL_ROOT}/bin/tmux-worktree create "add OAuth2 login"
# Output: WORKTREE_PATH=.worktrees/add-oauth2-login
#         BRANCH_NAME=feature/add-oauth2-login

# 2. Setup tmux with AI
${SKILL_ROOT}/bin/tmux-worktree setup ".worktrees/add-oauth2-login" "add-oauth2-login" "claude" "Add OAuth2 login"
# Output: SESSION=worktree-session WINDOW=add-oauth2-login AI_TOOL=claude

# 3. (Later) Check status
${SKILL_ROOT}/bin/tmux-worktree list

# 4. (Later) Cleanup
${SKILL_ROOT}/bin/tmux-worktree cleanup
```

## See Also

- Usage examples: Run `tmux-worktree --help` for usage information
