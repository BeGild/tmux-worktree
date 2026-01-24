# tmux-worktree Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build an Agent Skill that creates isolated git worktree development environments with tmux sessions and AI tool integration.

**Architecture:** Bash-based scripts for git/tmux operations, YAML configuration, Agent Skills specification format.

**Tech Stack:** Bash, Git, Tmux, YAML, Agent Skills specification.

---

## Task 1: Create project directory structure

**Files:**
- Create: `tmux-worktree/` (skill root directory)
- Create: `tmux-worktree/scripts/`
- Create: `tmux-worktree/references/`
- Create: `tmux-worktree/assets/`
- Create: `tests/`

**Step 1: Create directory structure**

```bash
mkdir -p tmux-worktree/scripts
mkdir -p tmux-worktree/references
mkdir -p tmux-worktree/assets
mkdir -p tests
```

**Step 2: Verify structure**

```bash
ls -la tmux-worktree/
```

Expected output: `scripts/`, `references/`, `assets/` directories

**Step 3: Commit**

```bash
git add tmux-worktree tests
git commit -m "chore: create project directory structure"
```

---

## Task 2: Create config template

**Files:**
- Create: `tmux-worktree/assets/config-template.yaml`

**Step 1: Create config template**

```bash
cat > tmux-worktree/assets/config-template.yaml << 'EOF'
# tmux-worktree configuration
# Place this at: ~/.config/tmux-worktree/config.yaml

# AI tool to launch in the tmux window
# Use {prompt} as placeholder for the user's prompt
ai_command: "claude {prompt}"

# Directory for worktree creation (relative to git repo root)
worktree_dir: ".worktrees"

# Prefix for generated branch names
branch_prefix: "feature/"

# Text appended to prompts to instruct AI where to save results
result_prompt_suffix: |
  Please save your final results to a file named RESULT.md in the current directory.
  Include a summary of changes, files modified, testing notes, and any next steps.
EOF
```

**Step 2: Verify file**

```bash
cat tmux-worktree/assets/config-template.yaml
```

Expected: YAML config with ai_command, worktree_dir, branch_prefix, result_prompt_suffix

**Step 3: Commit**

```bash
git add tmux-worktree/assets/config-template.yaml
git commit -m "feat: add config template"
```

---

## Task 3: Create create-worktree.sh script

**Files:**
- Create: `tmux-worktree/scripts/create-worktree.sh`

**Step 1: Create the script**

```bash
cat > tmux-worktree/scripts/create-worktree.sh << 'EOF'
#!/bin/bash
set -e

TASK_NAME="$1"
BASE_DIR="${2:-.worktrees}"

# Validate inputs
if [ -z "$TASK_NAME" ]; then
  echo "Error: Task name is required" >&2
  exit 1
fi

# Check if we're in a git repo
if ! git rev-parse --git-dir > /dev/null 2>&1; then
  echo "Error: Not in a git repository" >&2
  exit 1
fi

# Generate slug from task name
SLUG=$(echo "$TASK_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-')
BASE_BRANCH="feature/$SLUG"

# Get existing branches
EXISTING=$(git branch 2>/dev/null | sed 's/^[* ] //')

# Find unique branch name
if echo "$EXISTING" | grep -q "^$BASE_BRANCH$"; then
  # Extract existing numbers
  NUMS=$(echo "$EXISTING" | grep -E "^${BASE_BRANCH}-[0-9]+$" | sed "s/^${BASE_BRANCH}-//")
  if [ -n "$NUMS" ]; then
    MAX=$(echo "$NUMS" | sort -n | tail -1)
    BRANCH_NAME="${BASE_BRANCH}-$((MAX + 1))"
  else
    BRANCH_NAME="${BASE_BRANCH}-2"
  fi
else
  BRANCH_NAME="$BASE_BRANCH"
fi

# Create worktree
WORKTREE_PATH="${BASE_DIR}/${SLUG}"

# Check if worktree path already exists
if [ -d "$WORKTREE_PATH" ]; then
  # Add timestamp to make unique
  TIMESTAMP=$(date +%Y%m%d-%H%M%S)
  WORKTREE_PATH="${BASE_DIR}/${SLUG}-${TIMESTAMP}"
fi

git worktree add "$WORKTREE_PATH" -b "$BRANCH_NAME"

# Output metadata for caller
echo "WORKTREE_PATH=$WORKTREE_PATH"
echo "BRANCH_NAME=$BRANCH_NAME"
EOF
```

**Step 2: Make executable**

```bash
chmod +x tmux-worktree/scripts/create-worktree.sh
```

**Step 3: Verify executable**

```bash
ls -l tmux-worktree/scripts/create-worktree.sh
```

Expected: `-rwxr-xr-x` permissions

**Step 4: Commit**

```bash
git add tmux-worktree/scripts/create-worktree.sh
git commit -m "feat: add create-worktree.sh script"
```

---

## Task 4: Create setup-tmux.sh script

**Files:**
- Create: `tmux-worktree/scripts/setup-tmux.sh`

**Step 1: Create the script**

```bash
cat > tmux-worktree/scripts/setup-tmux.sh << 'EOF'
#!/bin/bash
set -e

WORKTREE_PATH="$1"
TASK_NAME="$2"
PROMPT="$3"

# Validate inputs
if [ -z "$WORKTREE_PATH" ] || [ -z "$TASK_NAME" ] || [ -z "$PROMPT" ]; then
  echo "Usage: $0 <worktree-path> <task-name> <prompt>" >&2
  exit 1
fi

# Load config
CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/tmux-worktree/config.yaml"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "Error: Config file not found at $CONFIG_FILE" >&2
  echo "Please create it from the template" >&2
  exit 1
fi

# Parse ai_command from config
AI_COMMAND=$(grep "^ai_command:" "$CONFIG_FILE" | cut -d':' -f2- | sed 's/^[[:space:]]*//')

# Parse result_prompt_suffix (multiline)
RESULT_SUFFIX=""
while IFS= read -r line; do
  if [[ "$line" == result_prompt_suffix:* ]]; then
    continue
  elif [[ "$line" == ^[a-z_]*: ]] && [ -n "$RESULT_SUFFIX" ]; then
    break
  elif [ -n "$line" ] || [ -n "$RESULT_SUFFIX" ]; then
    RESULT_SUFFIX="$RESULT_SUFFIX$line"$'\n'
  fi
done < "$CONFIG_FILE"

# Build full prompt with result suffix
FULL_PROMPT="$PROMPT"$'\n\n'"$RESULT_SUFFIX"

# Get tmux session name
if [ -n "$TMUX" ]; then
  SESSION_NAME=$(tmux display-message -p '#S')
else
  SESSION_NAME="worktree-session"
fi

# Window name (truncate to 20 chars)
WINDOW_NAME=$(echo "$TASK_NAME" | cut -c1-20)

# Check if tmux session exists
if ! tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
  tmux new-session -d -s "$SESSION_NAME" -n "$WINDOW_NAME" -c "$WORKTREE_PATH"
else
  tmux new-window -t "$SESSION_NAME" -n "$WINDOW_NAME" -c "$WORKTREE_PATH"
fi

# Construct AI command with prompt (escape single quotes in prompt)
ESCAPED_PROMPT=$(echo "$FULL_PROMPT" | sed "s/'/'\\\\''/g")
AI_CMD=$(echo "$AI_COMMAND" | sed "s/{prompt}/'${ESCAPED_PROMPT}'/")

# Send command to the window
tmux send-keys -t "$SESSION_NAME:$WINDOW_NAME" "$AI_CMD" C-m

# Output metadata for caller
echo "SESSION=$SESSION_NAME"
echo "WINDOW=$WINDOW_NAME"
EOF
```

**Step 2: Make executable**

```bash
chmod +x tmux-worktree/scripts/setup-tmux.sh
```

**Step 3: Verify executable**

```bash
ls -l tmux-worktree/scripts/setup-tmux.sh
```

Expected: `-rwxr-xr-x` permissions

**Step 4: Commit**

```bash
git add tmux-worktree/scripts/setup-tmux.sh
git commit -m "feat: add setup-tmux.sh script"
```

---

## Task 5: Create list-worktrees.sh script

**Files:**
- Create: `tmux-worktree/scripts/list-worktrees.sh`

**Step 1: Create the script**

```bash
cat > tmux-worktree/scripts/list-worktrees.sh << 'EOF'
#!/bin/bash
set -e

# Check if we're in a git repo
if ! git rev-parse --git-dir > /dev/null 2>&1; then
  echo "Error: Not in a git repository" >&2
  exit 1
fi

# Print header
printf "%-30s %-20s %-5s %s\n" "Branch" "Worktree" "Files" "Result"
printf "%-30s %-20s %-5s %s\n" "-------" "-------" "-----" "------"

WT_PATH=""
BRANCH=""

git worktree list --porcelain | while read -r line; do
  if [[ "$line" == worktree* ]]; then
    WT_PATH="${line#worktree }"
  elif [[ "$line" == branch* ]]; then
    BRANCH="${line#branch refs/heads/}"
    if [[ "$BRANCH" == refs/heads/* ]]; then
      BRANCH="${BRANCH#refs/heads/}"
    fi
  elif [[ "$line" == "" ]] && [ -n "$WT_PATH" ]; then
    # Empty line = end of worktree block
    if [ -d "$WT_PATH" ]; then
      cd "$WT_PATH" 2>/dev/null || continue
      STATUS=$(git status --short 2>/dev/null | wc -l)
      RESULT_FILE="RESULT.md"
      if [ -f "$RESULT_FILE" ]; then
        RESULT="✓ $(head -1 "$RESULT_FILE" | cut -c1-50)"
      else
        RESULT="-"
      fi
      WT_SHORT=$(basename "$WT_PATH")
      printf "%-30s %-20s %-5s %s\n" "$BRANCH" "$WT_SHORT" "$STATUS" "$RESULT"
    fi
    WT_PATH=""
    BRANCH=""
  fi
done
EOF
```

**Step 2: Make executable**

```bash
chmod +x tmux-worktree/scripts/list-worktrees.sh
```

**Step 3: Verify executable**

```bash
ls -l tmux-worktree/scripts/list-worktrees.sh
```

Expected: `-rwxr-xr-x` permissions

**Step 4: Commit**

```bash
git add tmux-worktree/scripts/list-worktrees.sh
git commit -m "feat: add list-worktrees.sh script"
```

---

## Task 6: Create cleanup.sh script

**Files:**
- Create: `tmux-worktree/scripts/cleanup.sh`

**Step 1: Create the script**

```bash
cat > tmux-worktree/scripts/cleanup.sh << 'EOF'
#!/bin/bash
set -e

# Check if we're in a git repo
if ! git rev-parse --git-dir > /dev/null 2>&1; then
  echo "Error: Not in a git repository" >&2
  exit 1
fi

# Get main branch
MAIN_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@refs/remotes/origin/@@')
if [ -z "$MAIN_BRANCH" ]; then
  MAIN_BRANCH="main"
fi

# Find candidates for cleanup
MAIN_Toplevel=$(git rev-parse --show-toplevel)

CANDIDATES=()
WT_PATH=""
BRANCH=""

git worktree list --porcelain | while read -r line; do
  if [[ "$line" == worktree* ]]; then
    WT_PATH="${line#worktree }"
  elif [[ "$line" == branch* ]]; then
    BRANCH="${line#branch refs/heads/}"
    if [[ "$BRANCH" == refs/heads/* ]]; then
      BRANCH="${BRANCH#refs/heads/}"
    fi
  elif [[ "$line" == "" ]] && [ -n "$WT_PATH" ]; then
    # Skip main worktree
    if [ "$WT_PATH" != "$MAIN_Toplevel" ]; then
      cd "$WT_PATH" 2>/dev/null || continue

      # Check if branch is merged to main
      IS_MERGED=0
      if git show-ref --verify --quiet "refs/heads/$BRANCH" 2>/dev/null; then
        IS_MERGED=$(git branch --merged "$MAIN_BRANCH" 2>/dev/null | grep -c "$BRANCH" || echo "0")
      fi

      # Check for commits
      HAS_COMMITS=$(git log --oneline 2>/dev/null | wc -l)

      # Candidate if merged or no commits
      if [ "$IS_MERGED" -gt 0 ] || [ "$HAS_COMMITS" -eq 0 ]; then
        REASON=""
        if [ "$IS_MERGED" -gt 0 ]; then
          REASON="(merged to $MAIN_BRANCH)"
        else
          REASON="(no commits)"
        fi

        echo "$WT_PATH|$BRANCH|$REASON"
      fi
    fi
    WT_PATH=""
    BRANCH=""
  fi
done | while IFS='|' read -r WT_PATH BRANCH REASON; do
  echo "Remove $BRANCH $REASON?"
  echo "  Path: $WT_PATH"
  read -r -p "[y/N] " ANSWER
  if [ "$ANSWER" = "y" ] || [ "$ANSWER" = "Y" ]; then
    git worktree remove "$WT_PATH" 2>/dev/null || rm -rf "$WT_PATH"
    if git show-ref --verify --quiet "refs/heads/$BRANCH" 2>/dev/null; then
      git branch -d "$BRANCH" 2>/dev/null || echo "Warning: Could not delete branch $BRANCH"
    fi
    echo "✓ Removed: $BRANCH"
  else
    echo "Skipped: $BRANCH"
  fi
  echo ""
done
EOF
```

**Step 2: Make executable**

```bash
chmod +x tmux-worktree/scripts/cleanup.sh
```

**Step 3: Verify executable**

```bash
ls -l tmux-worktree/scripts/cleanup.sh
```

Expected: `-rwxr-xr-x` permissions

**Step 4: Commit**

```bash
git add tmux-worktree/scripts/cleanup.sh
git commit -m "feat: add cleanup.sh script"
```

---

## Task 7: Create SKILL.md

**Files:**
- Create: `tmux-worktree/SKILL.md`

**Step 1: Create SKILL.md**

```bash
cat > tmux-worktree/SKILL.md << 'EOF'
---
name: tmux-worktree
description: Creates isolated git worktree development environments with tmux sessions and AI tool integration. Use when starting new features, bug fixes, or experiments that need isolated git context and AI assistance. Automatically manages branch naming, creates dedicated tmux windows, and captures AI results.

metadata:
  author: ekko.bao
  version: "1.0.0"

compatibility: Requires git, tmux, and a configured AI tool (claude, cursor, aider, etc.)
---

## Overview

This skill creates isolated development environments for AI-assisted tasks. Each task gets:
- A fresh git worktree with a uniquely named branch
- A dedicated tmux window with your AI tool pre-loaded
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
3. **AI tool configured** - Set up in `~/.config/tmux-worktree/config.yaml`
4. **Config file exists** - Create from template if missing

## Configuration

Config location: `~/.config/tmux-worktree/config.yaml`

If missing, create from the template:
```bash
mkdir -p ~/.config/tmux-worktree
cp [skill-path]/assets/config-template.yaml ~/.config/tmux-worktree/config.yaml
```

Key settings:
- `ai_command` - The AI tool to launch (use `{prompt}` placeholder)
- `worktree_dir` - Where worktrees are created
- `branch_prefix` - Branch name prefix

## Workflow

### 1. Create a New Worktree Session

When the user wants to start a new task:

**Step-by-step:**

1. Generate a task slug from the user's description
2. Run `scripts/create-worktree.sh "<task-name>"`
3. Parse output for `WORKTREE_PATH` and `BRANCH_NAME`
4. Run `scripts/setup-tmux.sh "<worktree-path>" "<task-name>" "<prompt>"`
5. Inform the user the environment is ready

**Example:**
```bash
# Create the worktree
./tmux-worktree/scripts/create-worktree.sh "add OAuth2 login"
# Output: WORKTREE_PATH=.worktrees/add-oauth2-login
#         BRANCH_NAME=feature/add-oauth2-login

# Setup tmux with AI
./tmux-worktree/scripts/setup-tmux.sh ".worktrees/add-oauth2-login" "add-oauth2-login" "Add OAuth2 login"
# Output: SESSION=worktree-session WINDOW=add-oauth2-login
```

### 2. Query Worktree Status

When the user asks about active worktrees:

Run `scripts/list-worktrees.sh` and display the output.

### 3. View AI Results

When the user asks about results from a specific task:

1. Navigate to the worktree directory
2. Read `RESULT.md` if it exists
3. Summarize the contents

### 4. Cleanup Completed Worktrees

When the user wants to clean up:

Run `scripts/cleanup.sh` - interactively prompts for each candidate.

## Branch Naming Strategy

- Base: `feature/<task-slug>`
- If exists: `feature/<task-slug>-2`, `-3`, etc.

## AI Prompt Format

Prompts are automatically appended with result suffix from config.

## Error Handling

- Not in git repo → Clear error message
- Worktree path exists → Uses timestamp suffix
- Tmux not running → Creates session automatically

## See Also

- [references/CONFIG.md](references/CONFIG.md) - Configuration details
- [references/EXAMPLES.md](references/EXAMPLES.md) - Usage examples
EOF
```

**Step 2: Verify file**

```bash
head -20 tmux-worktree/SKILL.md
```

Expected: YAML frontmatter with name, description, metadata

**Step 3: Commit**

```bash
git add tmux-worktree/SKILL.md
git commit -m "feat: add SKILL.md"
```

---

## Task 8: Create reference documentation

**Files:**
- Create: `tmux-worktree/references/CONFIG.md`
- Create: `tmux-worktree/references/EXAMPLES.md`

**Step 1: Create CONFIG.md**

```bash
cat > tmux-worktree/references/CONFIG.md << 'EOF'
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

### branch_prefix

Prefix for generated branch names.

**Default:** `feature/`

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
branch_prefix: "feature/"
result_prompt_suffix: |
  Please save your final results to a file named RESULT.md in the current directory.
```
EOF
```

**Step 2: Create EXAMPLES.md**

```bash
cat > tmux-worktree/references/EXAMPLES.md << 'EOF'
# Usage Examples

## Creating a new worktree session

```
User: I need to add OAuth2 login to the app

Agent: Creates worktree at `.worktrees/add-oauth2-login`
       Creates branch `feature/add-oauth2-login`
       Opens tmux window "add-oauth2-login"
       Launches: `claude "Add OAuth2 login..."`

Result: Fresh tmux window with Claude ready.
```

## Querying worktree status

```
User: Show me all my active worktrees

Output:
add-oauth2-login    .worktrees/add-oauth2-login   3    ✓ Added OAuth flow...
fix-login-bug       .worktrees/fix-login-bug-2    1    ✓ Fixed password val...
refactor-auth       .worktrees/refactor-auth      0    -
```

## Viewing AI results

```
User: What were the results from the OAuth2 work?

Agent: Reads .worktrees/add-oauth2-login/RESULT.md

# OAuth2 Implementation Summary

## Changes Made
- Added Google OAuth2 provider
- Created /auth/callback endpoint

## Files Modified
- src/auth/oauth.ts (new)
- src/auth/session.ts
```

## Cleanup workflow

```
User: Clean up my completed worktrees

Remove feature/add-oauth2-login? (already merged) [y/N]: y
✓ Removed feature/add-oauth2-login
```
EOF
```

**Step 3: Verify files**

```bash
ls -la tmux-worktree/references/
```

Expected: `CONFIG.md`, `EXAMPLES.md`

**Step 4: Commit**

```bash
git add tmux-worktree/references/
git commit -m "feat: add reference documentation"
```

---

## Task 9: Create install.sh script

**Files:**
- Create: `install.sh`

**Step 1: Create install.sh**

```bash
cat > install.sh << 'EOF'
#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$SCRIPT_DIR/tmux-worktree"

# Check if skill directory exists
if [ ! -d "$SKILL_DIR" ]; then
  echo "Error: tmux-worktree skill directory not found at: $SKILL_DIR" >&2
  exit 1
fi

# Detect skills directory (Claude Code)
SKILLS_DEST="${XDG_CONFIG_HOME:-$HOME/.config}/claude/skills"

if [ ! -d "$SKILLS_DEST" ]; then
  echo "Creating skills directory: $SKILLS_DEST"
  mkdir -p "$SKILLS_DEST"
fi

# Copy skill
echo "Installing skill to: $SKILLS_DEST"
cp -r "$SKILL_DIR" "$SKILLS_DEST/"

# Create config directory and template
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/tmux-worktree"
mkdir -p "$CONFIG_DIR"

if [ ! -f "$CONFIG_DIR/config.yaml" ]; then
  cp "$SKILL_DIR/assets/config-template.yaml" "$CONFIG_DIR/config.yaml"
  echo "Created config: $CONFIG_DIR/config.yaml"
  echo "Please edit this file to configure your AI tool."
else
  echo "Config already exists: $CONFIG_DIR/config.yaml"
fi

echo ""
echo "Installation complete!"
echo "Skill installed at: $SKILLS_DEST/tmux-worktree"
echo "Config location: $CONFIG_DIR/config.yaml"
EOF
```

**Step 2: Make executable**

```bash
chmod +x install.sh
```

**Step 3: Verify executable**

```bash
ls -l install.sh
```

Expected: `-rwxr-xr-x` permissions

**Step 4: Commit**

```bash
git add install.sh
git commit -m "feat: add install.sh script"
```

---

## Task 10: Create README.md

**Files:**
- Create: `README.md`

**Step 1: Create README.md**

```bash
cat > README.md << 'EOF'
# tmux-worktree

An Agent Skill that creates isolated git worktree development environments with tmux sessions and AI tool integration.

## Overview

tmux-worktree automates the creation of isolated development environments for AI-assisted tasks. Each task gets:
- A fresh git worktree with a uniquely named branch
- A dedicated tmux window with your AI tool pre-loaded
- Automatic result capture via RESULT.md files

## Installation

```bash
git clone https://github.com/ekko.bao/tmux-worktree.git
cd tmux-worktree
./install.sh
```

## Configuration

Edit `~/.config/tmux-worktree/config.yaml` to set your AI tool:

```yaml
ai_command: "claude {prompt}"  # or cursor, aider, etc.
worktree_dir: ".worktrees"
branch_prefix: "feature/"
```

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
EOF
```

**Step 2: Verify file**

```bash
cat README.md
```

Expected: README with overview, installation, configuration, usage sections

**Step 3: Commit**

```bash
git add README.md
git commit -m "docs: add README.md"
```

---

## Task 11: Create test workflow

**Files:**
- Create: `tests/test-workflow.sh`

**Step 1: Create test script**

```bash
cat > tests/test-workflow.sh << 'EOF'
#!/bin/bash
set -e

echo "=== tmux-worktree Workflow Test ==="
echo ""

# Create temp repo
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"
git init
git config user.name "Test User"
git config user.email "test@example.com"
echo "# Test" > README.md
git add README.md
git commit -m "Initial commit"

echo "Test repo created: $TEMP_DIR"
echo ""

# Test 1: Create worktree
echo "Test 1: Create worktree"
bash ../tmux-worktree/scripts/create-worktree.sh "test feature"
echo "✓ Worktree created"
echo ""

# Test 2: List worktrees
echo "Test 2: List worktrees"
bash ../tmux-worktree/scripts/list-worktrees.sh
echo "✓ List works"
echo ""

# Cleanup
cd -
rm -rf "$TEMP_DIR"

echo "=== All tests passed ==="
EOF
```

**Step 2: Make executable**

```bash
chmod +x tests/test-workflow.sh
```

**Step 3: Verify executable**

```bash
ls -l tests/test-workflow.sh
```

Expected: `-rwxr-xr-x` permissions

**Step 4: Commit**

```bash
git add tests/test-workflow.sh
git commit -m "test: add workflow test script"
```

---

## Task 12: Add .gitignore

**Files:**
- Create: `.gitignore`

**Step 1: Create .gitignore**

```bash
cat > .gitignore << 'EOF'
# Worktrees
.worktrees/

# Test artifacts
*.tmp
tmp/
EOF
```

**Step 2: Verify file**

```bash
cat .gitignore
```

Expected: `.worktrees/`, `*.tmp`, `tmp/`

**Step 3: Commit**

```bash
git add .gitignore
git commit -m "chore: add .gitignore"
```

---

## Task 13: Final verification

**Files:**
- Verify: All files created correctly

**Step 1: Verify directory structure**

```bash
tree -L 2 tmux-worktree/
```

Expected:
```
tmux-worktree/
├── SKILL.md
├── assets/
│   └── config-template.yaml
├── references/
│   ├── CONFIG.md
│   └── EXAMPLES.md
└── scripts/
    ├── cleanup.sh
    ├── create-worktree.sh
    ├── list-worktrees.sh
    └── setup-tmux.sh
```

**Step 2: Verify all scripts are executable**

```bash
ls -l tmux-worktree/scripts/
```

Expected: All files have `-rwxr-xr-x` permissions

**Step 3: Verify install.sh is executable**

```bash
ls -l install.sh
```

Expected: `-rwxr-xr-x` permissions

**Step 4: Count files**

```bash
find tmux-worktree -type f | wc -l
```

Expected: 8 files (SKILL.md, 4 scripts, 2 references, 1 asset)

**Step 5: Commit final state**

```bash
git add -A
git commit -m "chore: final project structure verification"
```

---

## Task 14: Run integration test

**Files:**
- Test: `tests/test-workflow.sh`

**Step 1: Run workflow test**

```bash
./tests/test-workflow.sh
```

Expected output: All tests pass

**Step 2: If test passes, add test commit**

```bash
git commit --allow-empty -m "test: integration tests passing"
```

---

## Task 15: Create design document

**Files:**
- Create: `docs/plans/2025-01-28-tmux-worktree-design.md`

**Step 1: Copy design document**

The design document has already been created at `docs/plans/2025-01-28-tmux-worktree-design.md`

**Step 2: Verify design doc exists**

```bash
ls -la docs/plans/
```

Expected: Design document present

**Step 3: Commit design doc**

```bash
git add docs/plans/
git commit -m "docs: add design document"
```

---

## Completion Checklist

- [ ] All scripts created and executable
- [ ] SKILL.md follows Agent Skills specification
- [ ] Config template created
- [ ] Reference docs created
- [ ] Install script works
- [ ] README.md complete
- [ ] Tests passing
- [ ] Design document saved
- [ ] All commits made
