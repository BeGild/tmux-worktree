# tmux-worktree

An Agent Skill that creates isolated git worktree development environments with tmux sessions and AI tool integration.

## Overview

tmux-worktree automates the creation of isolated development environments for AI-assisted tasks. Each task gets:

- A fresh git worktree with a uniquely named branch
- A dedicated tmux window with your AI tool pre-loaded
- Automatic result capture via RESULT.md files

## Installation

### Via Plugin Marketplace (Recommended)

```bash
# Add the marketplace
/plugin marketplace add BeGild/ekko-marketplace

# Install the plugin
/plugin install tmux-worktree@ekko-marketplace
```

### Via Local Plugin Directory

```bash
# Clone the repository
git clone https://github.com/BeGild/tmux-worktree.git
cd tmux-worktree

# Install with local plugin directory
claude --plugin-dir ./
```

### Legacy Installation

```bash
git clone https://github.com/BeGild/tmux-worktree.git
cd tmux-worktree
./install.sh
```

## Configuration

Edit `~/.config/tmux-worktree/config.yaml` to set your AI tool:

```yaml
ai_command: "claude {prompt}" # or cursor, aider, etc.
worktree_dir: ".worktrees"

# Text appended to prompts to instruct AI where to save results
result_prompt_suffix: |
  Please save your final results to a file named RESULT.md in the current directory.
  Include a summary of changes, files modified, testing notes, and any next steps.
```

**Note:** Branch names use the `feature/` prefix by default (hardcoded in scripts).

## Usage (via AI Agent)

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
