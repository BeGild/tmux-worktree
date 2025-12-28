# Tmux Worktree - Reference

Detailed command reference and configuration.

## Commands

### tm-task

```bash
tm-task <branch-name> <task-description> [ai-command]
```

| Argument | Required | Description |
|----------|----------|-------------|
| `branch-name` | Yes | Git branch name to create |
| `task-description` | Yes | Task description (injected into AI context) |
| `ai-command` | No | AI command (default: `claude`) |

#### AI Commands

| Command | Description |
|---------|-------------|
| `claude` | Claude Code (default) |
| `codex` | OpenAI Codex |
| `<custom>` | Any custom shell command |

#### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `TM_TASK_WORKTREE_BASE` | `~/.local/tmux-git-worktrees` | Worktree storage |
| `TM_TASK_SKILL_ENABLED` | `true` | Enable skill injection |
| `TM_TASK_DEBUG` | `false` | Debug logging |
| `TM_TASK_AI_CMD_<tool>` | (default) | Custom AI launch command |

#### Custom AI Launch Commands

Override the default launch command for any AI tool using environment variables:

```bash
# Use a completely custom AI wrapper
export TM_TASK_AI_CMD_MYAI="my-ai-wrapper --context-file CONTEXT.md"

# Then use normally
tm-task my-task "task description" myai
```

### tm-recover

```bash
tm-recover <command>
```

| Command | Description |
|---------|-------------|
| `list` | List all orphaned resources |
| `windows` | List hidden tm-task windows |
| `worktrees` | List orphaned worktrees |
| `clean` | Clean up orphaned resources |
| `attach <id>` | Attach to hidden window |

## How It Works

### The Pane Swap

```
Before:                    After:
┌────┬────┬────┬────┐     ┌────┬────┬────┬────┐
│ A  │ B  │ C  │ D  │ ──> │ A  │ B' │ C  │ D  │
│code│work│log │test│     │code│task│log │test│
└────┴────┴────┴────┘     └────┴────┴────┴────┘
     ↓                          ↓
  Original                   Task pane
  saved to background        in same spot
```

### Execution Flow

1. **Snapshot** - Capture current pane ID
2. **Setup** - Create hidden window with task pane
3. **Create** - `git worktree add` creates isolated environment
4. **Inject** - Task context written to `.claude/skills/task-context/SKILL.md`
5. **Swap** - `tmux swap-pane` exchanges panes
6. **Launch** - AI tool starts with auto-loaded context
7. **Restore** - On exit, panes swap back, worktree cleaned up
