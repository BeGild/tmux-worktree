---
name: tmux-git-worktree
description: Tmux + Git Worktree context switcher. Creates isolated task environments with automatic pane swapping and AI context injection. Use when you need to work on temporary tasks without disturbing your main workspace.
allowed-tools: Bash, Read, Edit, Write
---

# Tmux Git Worktree Skill

A Tmux + Git Worktree workflow tool for **in-place context swapping**.

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
2. Swaps current tmux pane with task environment
3. Preserves all other panes (logs, docs, references)
4. Auto-injects task context into AI
5. Restores original pane on exit

## Documentation

- **[[reference.md]]** - Detailed command reference, configuration, and API
- **[[examples.md]]** - Usage examples and workflows

## Scripts

This skill includes executable scripts in `scripts/`:

- `tm-task` - Main CLI for creating task environments
- `tm-recover` - Recovery tool for orphaned sessions
