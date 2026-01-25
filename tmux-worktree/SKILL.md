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
3. **AI tool configured** - Set up in `~/.config/tmux-worktree/config.json`
4. **Config file exists** - Create from template if missing

## Configuration

Config location: `~/.config/tmux-worktree/config.json`

If missing, create from the template:

```bash
mkdir -p ~/.config/tmux-worktree
cp ./assets/config-template.json ~/.config/tmux-worktree/config.json
```

### Configuration Structure

```json
{
  "version": "2.0",
  "worktree_dir": ".worktrees",
  "default_ai": "claude",
  "result_prompt_suffix": "Global result suffix...",
  "ai_tools": {
    "claude": {
      "command": "claude '{prompt}'",
      "description": "Anthropic Claude AI assistant",
      "result_prompt_suffix": "Optional tool-specific override"
    },
    "cursor": {
      "command": "cursor '{prompt}'",
      "description": "Cursor AI IDE integration"
    }
  }
}
```

### Key Settings

- `version` - Config schema version (for future migrations)
- `worktree_dir` - Directory for worktree creation (relative to git repo root)
- `default_ai` - Default AI tool to use when none is specified
- `result_prompt_suffix` - Global text appended to prompts for result capture
- `ai_tools` - Object containing AI tool configurations
  - Each tool must have: `command` (with `{prompt}` placeholder) and `description`
  - Optional `result_prompt_suffix` overrides the global setting

## Workflow

### 1. Create a New Worktree Session

When the user wants to start a new task:

**Step-by-step:**

1. Load the config from `~/.config/tmux-worktree/config.json`
2. Check available AI tools from `config.ai_tools`
3. **Interactive AI Selection:**
   - If only one AI tool is configured, use it automatically
   - If multiple AI tools are configured, use `AskUserQuestion` to let the user choose
4. Generate a task slug from the user's description
5. Run `tmux-worktree create "<task-name>"`
6. Parse output for `WORKTREE_PATH` and `BRANCH_NAME`
7. Run `tmux-worktree setup "<worktree-path>" "<task-name>" "<ai-tool>" "<prompt>"`
8. Inform the user the environment is ready

**Interactive AI Selection with AskUserQuestion:**

```javascript
{
  "questions": [{
    "question": "选择AI工具用于此任务：",
    "header": "AI工具",
    "options": Object.entries(config.ai_tools).map(([key, tool]) => ({
      "label": key,
      "description": tool.description
    })),
    "multiSelect": false
  }]
}
```

**Example:**

```bash
# Create the worktree
tmux-worktree create "add OAuth2 login"
# Output: WORKTREE_PATH=.worktrees/add-oauth2-login
#         BRANCH_NAME=feature/add-oauth2-login

# Setup tmux with AI (claude selected interactively)
tmux-worktree setup ".worktrees/add-oauth2-login" "add-oauth2-login" "claude" "Add OAuth2 login"
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

## AI Prompt Format

Prompts are automatically appended with result suffix:

1. Tool-specific `result_prompt_suffix` (if defined)
2. Otherwise, global `result_prompt_suffix` from config

## Error Handling

- Not in git repo → Clear error message
- Worktree path exists → Uses timestamp suffix
- Tmux not running → Creates session automatically
- AI tool not found → Lists available tools
- Config file missing → Instructions to create from template

## See Also

- Configuration details: See `assets/config-template.json` for all available settings
- Usage examples: Run `tmux-worktree --help` for usage information
