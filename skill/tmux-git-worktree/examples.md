# Tmux Worktree - Examples

## Basic Usage

```bash
# Bug fix with Claude Code (default)
tm-task fix-auth-bug "修复登录接口的 CSRF 漏洞"

# Feature with Codex
tm-task feature-oauth "Add OAuth2 login" codex
```

## Workflows

### Workflow 1: Quick Bug Fix While Working

```
Your current layout:
┌───────────┬───────────┬───────────┐
│ Vim: feat │ Server    │ Tests     │
└───────────┴───────────┴───────────┘

Run: tm-task hotfix "Fix crash in production"

Layout becomes:
┌───────────┬───────────┬───────────┐
│ Vim: feat │ AI: hotfix│ Tests     │
│ (saved)   │ (working) │ (visible) │
└───────────┴───────────┴───────────┘

Fix the bug, referencing server logs...
exit

Layout restored to original
```

### Workflow 2: Parallel Features with Different AI

```bash
# Work on feature A with Claude Code
tm-task feature-a "Implement user profile" claude
exit

# Work on feature B with Codex
tm-task feature-b "Implement settings" codex
exit

# Each has isolated git history and AI context
```

## Configuration Examples

```bash
# Custom worktree location
export TM_TASK_WORKTREE_BASE=~/dev/worktrees

# Debug mode
TM_TASK_DEBUG=true tm-task my-task "description"

# Disable skills
export TM_TASK_SKILL_ENABLED=false
```
