---
name: tmux-git-worktree
description: Tmux + Git Worktree context switcher. Creates isolated task environments with automatic window creation and AI context injection. Use when you need to work on temporary tasks without disturbing your main workspace.
allowed-tools: Bash, Read, Edit, Write
---

# Tmux Git Worktree Skill

A Tmux + Git Worktree workflow tool for creating **isolated task environments**.

## Quick Start

```bash
# Create a task environment (default: Claude Code)
tm-task <branch-name> <task-description>

# Examples:
tm-task fix-auth-bug "fix login interface CSRF vulnerability"
tm-task feature-auth "Add OAuth2 login" codex
tm-task experiment "Try new approach" none
```

## What This Does

1. Creates a new git worktree in isolated directory
2. Creates a new tmux window (named after the branch)
3. Prepares context for AI to generate initial prompt
4. Auto-cleans worktree on exit (if no changes)

## AI Initial Prompt Requirement

**IMPORTANT:** When you invoke this skill to create a task environment, the AI should:

1. **Read the context file** (`CLAUDE.md` for Claude) that is created in the worktree
2. **Generate a complete initial prompt** that includes:
   - **Understanding** - Restate the task to confirm understanding
   - **Planning** - Outline the technical approach
   - **Implementation Steps** - Break down the work into specific steps
   - **Testing Strategy** - Describe how to verify the implementation

3. **Wait for user confirmation** before proceeding with implementation

Example initial prompt format:
```
# Initial Prompt for: <task description>

## My Understanding
[Restate the task to confirm understanding]

## My Approach
[Outline the technical approach]

## Implementation Plan
1. [Step 1]
2. [Step 2]
...

## Testing Strategy
[How to verify the implementation]

---
Ready to proceed. Please confirm or adjust this plan.
```

## Workflow

1. User runs `tm-task <branch> "<description>"`
2. A new tmux window opens with the worktree
3. AI tool launches with initial context prompt
4. AI generates initial plan for user approval
5. User approves the plan
6. AI implements the solution
7. **User closes the window** → worktree auto-cleans if no changes

## Documentation

- **[[reference.md]]** - Detailed command reference, configuration, and API
- **[[examples.md]]** - Usage examples and workflows

## Scripts

This skill includes executable scripts in `scripts/`:

- `tm-task` - Main CLI for creating task environments
- `tm-recover` - Recovery tool for orphaned sessions
