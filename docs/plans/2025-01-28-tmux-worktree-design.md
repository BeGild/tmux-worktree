# tmux-worktree Design Document

## Overview

**tmux-worktree** is an Agent Skill that creates isolated git worktree development environments with tmux sessions and AI tool integration. Each development task gets an isolated environment with a fresh git branch, a dedicated tmux window, and the user's preferred AI tool pre-loaded with the task prompt.

## Problem Statement

Developers often need to:
1. Work on multiple tasks simultaneously without context switching
2. Isolate changes in separate git branches
3. Use AI tools to help with implementation
4. Track progress across multiple worktrees

## Solution

A skill that automates:
- Git worktree creation with smart branch naming
- Tmux window creation for each task
- AI tool launch with pre-loaded prompt
- Result capture via RESULT.md files
- Worktree status querying and cleanup

## Architecture

### Entry Point
- **CLI command with arguments**: `tmux-worktree new <task-name> <prompt>`

### Core Components

**Scripts Layer** (`tmux-worktree/scripts/`):
- `create-worktree.sh` - Git worktree operations with smart branch naming
- `setup-tmux.sh` - Tmux window creation and AI tool launch
- `list-worktrees.sh` - Query worktree status
- `cleanup.sh` - Interactive cleanup of completed worktrees

**References** (`tmux-worktree/references/`):
- `CONFIG.md` - Configuration documentation
- `EXAMPLES.md` - Usage examples

**Assets** (`tmux-worktree/assets/`):
- `config-template.yaml` - Default configuration template

### Configuration

**Location**: `~/.config/tmux-worktree/config.yaml`

**Settings**:
```yaml
ai_command: "claude {prompt}"           # AI tool to launch
worktree_dir: ".worktrees"              # Worktree base directory
branch_prefix: "feature/"               # Branch name prefix
result_prompt_suffix: |                 # Appended to prompts
  Please save your final results to a file named RESULT.md...
```

### Data Flow

**Creating a new session:**
1. `create-worktree.sh` generates unique branch name and creates worktree
2. `setup-tmux.sh` creates tmux window and launches AI tool
3. AI tool generates `RESULT.md` in worktree directory

**Querying worktrees:**
1. `list-worktrees.sh` combines `git worktree list` with git status
2. Displays branch, path, modified files count, and RESULT.md status

**Cleanup:**
1. `cleanup.sh` identifies merged/abandoned branches
2. Interactive prompt for each candidate
3. Removes worktree and branch

### Branch Naming Strategy

Smart unique naming:
- Base: `feature/<task-slug>`
- If exists: `feature/<task-slug>-2`, `-3`, etc.
- Query existing branches to find next available number

### Project Structure

```
tmux-worktree/                      # Project root
├── tmux-worktree/                  # Agent Skill content (installable)
│   ├── SKILL.md                    # Main skill instructions
│   ├── scripts/
│   │   ├── create-worktree.sh
│   │   ├── setup-tmux.sh
│   │   ├── list-worktrees.sh
│   │   └── cleanup.sh
│   ├── references/
│   │   ├── CONFIG.md
│   │   └── EXAMPLES.md
│   └── assets/
│       └── config-template.yaml
├── install.sh                      # Installation script
├── README.md                       # Project documentation
└── tests/
    └── test-workflow.sh            # End-to-end workflow test
```

### Installation

```bash
git clone https://github.com/ekko.bao/tmux-worktree.git
cd tmux-worktree
./install.sh    # Copies tmux-worktree/ to ~/.claude/skills/
```

## Key Features

1. **Smart branch naming** - Automatically generates unique branch names
2. **Isolated environments** - Each task gets its own worktree and tmux window
3. **Configurable AI tools** - Supports any AI tool via config
4. **Result capture** - AI generates RESULT.md for easy review
5. **Interactive cleanup** - Safe removal of completed worktrees

## Error Handling

- Not in git repo → Clear error message
- Branch exists → Auto-increment suffix
- Tmux not running → Auto-create session
- Worktree path exists → Use timestamp/suffix
