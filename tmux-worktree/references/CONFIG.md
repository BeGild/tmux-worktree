# Configuration Reference

The tmux-worktree skill uses a configuration file at `~/.config/tmux-worktree/config.yaml`.

## Options

### ai_command

The AI tool command to run. Use `{prompt}` as a placeholder for the user's prompt.

**Default:** `claude {prompt}`

**Examples:**
```yaml
ai_command: "claude {prompt}"
ai_command: "cursor {prompt}"
ai_command: "aider --message '{prompt}'"
```

### worktree_dir

Directory where worktrees are created (relative to git repo root).

**Default:** `.worktrees`

### result_prompt_suffix

Text appended to every prompt to instruct AI where to save results.

**Default:**
```yaml
result_prompt_suffix: |
  Please save your final results to a file named RESULT.md in the current directory.
```

## Example Config

```yaml
ai_command: "claude {prompt}"
worktree_dir: ".worktrees"
result_prompt_suffix: |
  Please save your final results to a file named RESULT.md in the current directory.
```

**Note:** Branch names use the `feature/` prefix by default (hardcoded in scripts).
