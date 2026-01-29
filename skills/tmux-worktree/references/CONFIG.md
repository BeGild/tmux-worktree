# Configuration Reference

The tmux-worktree skill uses a JSON configuration file at `~/.config/tmux-worktree/config.json`.

## Options

### version

Configuration schema version.

**Current:** `2.0`

### default_ai

The default AI tool to use when running tmux setup.

**Required:** No (if omitted, uses first tool in `ai_tools`)

**Example:** `"claude"`

### ai_tools

Object defining available AI tools and their configurations.

**Required:** Yes

Each tool must have:
- `command` - The shell command to run the AI tool
- `description` - Human-readable description of the tool

**Note:** The command will receive input via stdin from `.tmux-worktree/prompt.md`. Do NOT use `{prompt}` placeholder.

**Example:**
```json
{
  "ai_tools": {
    "claude": {
      "command": "claude",
      "description": "Anthropic Claude AI assistant"
    },
    "cursor": {
      "command": "cursor",
      "description": "Cursor AI editor"
    }
  }
}
```

## Example Config

```json
{
  "version": "2.0",
  "default_ai": "claude",
  "ai_tools": {
    "claude": {
      "command": "claude",
      "description": "Anthropic Claude AI assistant"
    },
    "aider": {
      "command": "aider --message",
      "description": "Aider AI coding assistant"
    }
  }
}
```

## Notes

- Worktrees are always created in `.worktrees/` directory
- Each worktree contains `.tmux-worktree/` directory:
  - `prompt.md` - Original task prompt (saved during setup)
  - `progress.md` - Progress tracking (updated during work)
- AI tools are invoked via `cat .tmux-worktree/prompt.md | <command>`
- **Command receives input via stdin, not via `{prompt}` placeholder**
