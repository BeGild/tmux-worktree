# tmux-worktree

An Agent Skill that creates isolated git worktree development environments with tmux sessions and AI tool integration.

## Overview

tmux-worktree automates the creation of isolated development environments for AI-assisted tasks. Each task gets:

- A fresh git worktree with a uniquely named branch
- A dedicated tmux window with your AI tool pre-loaded
- Automatic result capture via RESULT.md files

## Installation

### Via Claude Code Plugin (Recommended)

```bash
# Install directly from GitHub
/plugin install https://github.com/BeGild/tmux-worktree.git

# Or install from local directory
/plugin install /path/to/tmux-worktree
```

After installation, use the skill via slash command:

```
/tmux-worktree:tmux-worktree
```

### Manual Setup

```bash
# Clone the repository
git clone https://github.com/BeGild/tmux-worktree.git
cd tmux-worktree

# Add bin directory to PATH (optional)
export PATH="$PATH:$(pwd)/skills/tmux-worktree/bin"
```

## Configuration

Edit `~/.config/tmux-worktree/config.json` to set your AI tool:

```json
{
  "version": "2.0",
  "worktree_dir": ".worktrees",
  "default_ai": "claude",
  "result_prompt_suffix": "## RESULT_SUMMARY\nPlease save your final results to a file named RESULT.md in the current directory.\n\n1.Include a summary of changes, files modified, testing notes, and any next steps.\n2. Length <= 300 characters",
  "ai_tools": {
    "claude": {
      "command": "claude '{prompt}'",
      "description": "Anthropic Claude AI assistant"
    }
  }
}
```

**Note:** Branch names use the `feature/` prefix by default.

## Usage

### Via Slash Command

After installing the plugin, use the slash command:

```
/worktree
```

Example session:

```
User: /worktree

Agent: I'll help you create an isolated worktree environment.
       [Prompts for task description]
       [Creates worktree at .worktrees/<task-name>]
       [Creates branch feature/<task-name>]
       [Opens tmux window with AI tool ready]
```

### Via AI Agent

When working with an AI agent that supports Agent Skills:

```
User: I need to add OAuth2 login to the app

Agent: [Uses tmux-worktree skill]
       → Creates worktree at .worktrees/add-oauth2-login
       → Creates branch feature/add-oauth2-login
       → Opens tmux window with Claude ready
```

## Features

- Smart branch naming (auto-increments if exists)
- Isolated git worktrees for parallel work
- Tmux integration for organized sessions
- Configurable AI tools
- Result capture via RESULT.md
- Interactive cleanup

## Requirements

- Git
- Tmux
- An AI tool (claude, cursor, aider, etc.)
- An AI agent that supports Agent Skills

## License

MIT
