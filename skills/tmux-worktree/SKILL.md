---
name: tmux-worktree
description: Creates isolated git worktree development environments with tmux sessions. Use when starting new features, bug fixes, or experiments that need isolated git context. Automatically manages branch naming, creates dedicated tmux windows.
---

## Skill Root Location

**SKILL_ROOT** = Directory containing this SKILL.md file (NOT `pwd`)

## Overview

This skill creates isolated development environments for AI-assisted tasks. Each task gets:

- A fresh git worktree with a uniquely named branch
- **Parent branch tracking** - Records the branch you started from (for correct merge targets)
- A dedicated tmux window with your AI tool pre-loaded
- Interactive AI tool selection (when multiple tools configured)
- **Prompt persistence via `.tmux-worktree/prompt.md` for task traceability**
- **Progress tracking via `.tmux-worktree/progress.md`**

## Prompt Template

Before calling `tmux-worktree setup`, **you MUST structure your prompt** following this template:

```markdown
# Task: {任务名称}

## Context

- **Branch**: {分支名}
- **Worktree**: {worktree相对路径}

## Objective

{清晰描述任务目标，1-2句话}

## Original Request

{用户的原始请求内容}

## Constraints

- 工作目录限制在当前 worktree 内
- 完成后更新 .tmux-worktree/progress.md 记录结果
- 遵循项目的代码规范

## Success Criteria

{明确任务完成的验收标准}
```

**Example:**

```
# Task: Add OAuth2 Login

## Context
- **Branch**: feature/add-oauth2-login
- **Worktree**: .worktrees/add-oauth2-login

## Objective
Implement OAuth2 authentication flow allowing users to login with Google and GitHub.

## Original Request
用户要求添加 Google 和 GitHub 的 OAuth2 登录功能...

## Constraints
- 工作目录限制在当前 worktree 内
- 完成后更新 .tmux-worktree/progress.md 记录结果
- 遵循项目的代码规范

## Success Criteria
- 用户可以使用 Google 账号登录
- 用户可以使用 GitHub 账号登录
- Token 正确保存到数据库
- 测试覆盖主要场景
```

## When to Use

Use this skill when:

- Starting a new feature, bug fix, or experiment
- The user mentions "new branch", "isolated environment", "worktree"
- You need to work on multiple tasks simultaneously
- The user wants AI assistance on a specific task

## Prerequisites

1. **Git repository** - Must be run from within a git repo
2. **tmux installed** - For window/session management
3. **AI tool configured** - Run `${SKILL_ROOT}/bin/tmux-worktree query-config` to check available tools

### Project Setup (First Time Only)

**Required .gitignore entries:**

Before creating your first worktree, ensure your `.gitignore` includes:

```gitignore
# Worktrees
.worktrees/

# Tmux-worktree task management
.tmux-worktree/
```

**Verify with:** `cat .gitignore | grep -E "worktrees|tmux-worktree"`

If missing, add these entries to prevent worktree directories and task files from being committed.

## Worktree Task Lifecycle

> **Task Checklist** - Track progress with TodoWrite:
>
> - [ ] **CREATE** - Set up new worktree environment
> - [ ] **WORK** - AI-assisted development in isolated environment
> - [ ] **CLEANUP** - Query status, review results, remove worktree

### Phase 1: CREATE

Start a new isolated development environment.

**When to use:** User wants to start a new feature, bug fix, or experiment.

**Step-by-step:**

0. **Pre-check**: Verify `.gitignore` is configured

   ```bash
   cat .gitignore | grep -E "worktrees|tmux-worktree"
   # If missing, add: .worktrees/ and .tmux-worktree/
   ```

1. **Generate structured prompt** (follow the Prompt Template above)
2. Query available AI tools: `${SKILL_ROOT}/bin/tmux-worktree query-config`
3. **Interactive AI Selection:**
   - If only one AI tool → use it automatically
   - If multiple AI tools → use `AskUserQuestion` to let user choose
4. Generate a task slug from user's description
5. Run: `${SKILL_ROOT}/bin/tmux-worktree create "<task-name>"`
6. Parse output for `WORKTREE_PATH` and `BRANCH_NAME`
7. Run: `${SKILL_ROOT}/bin/tmux-worktree setup "<worktree-path>" "<task-name>" "<ai-tool>" "<structured-prompt>"`
   - **Note**: The script will save your prompt to `.tmux-worktree/prompt.md`
   - **Note**: The script will invoke AI via `cat .tmux-worktree/prompt.md | ai-tool`
8. Inform user the environment is ready

**AI Responsibility:**

- Verify `.gitignore` configuration
- Guide AI tool selection when multiple options exist
- Confirm environment is ready before proceeding

### Phase 2: WORK

AI-assisted development happens in the isolated worktree.

**Key behaviors:**

- All work stays in the worktree directory
- Branch is isolated from main/master
- AI tool runs in dedicated tmux window
- **`.tmux-worktree/prompt.md` contains the original task definition**
- **`.tmux-worktree/progress.md` tracks progress and final results**

**Transition trigger:** User signals completion or asks to clean up

### Phase 3: CLEANUP

Remove completed worktrees after preserving results.

**When to use:** Task is complete or user wants to clean up.

**Step-by-step:**

1. **Query status:** `${SKILL_ROOT}/bin/tmux-worktree list`
   - Always show current state before cleanup
2. **Review progress:** `cat .worktrees/<task-name>/.tmux-worktree/progress.md` (if exists)
   - Offer to show progress.md contents for tasks being removed
3. **Interactive cleanup:** `${SKILL_ROOT}/bin/tmux-worktree cleanup`
   - Guides user through prompts for each candidate

**AI Responsibility:**

- ALWAYS run `list` before cleanup to show current state
- **Shows Status from progress.md (In Progress/Waiting for User/Completed/Blocked/Abandoned)**
- Offer to display progress.md before removing worktrees
- Guide user through interactive cleanup prompts
- Confirm removal was successful

**DO NOT SKIP:** Always complete cleanup after tasks finish to prevent worktree accumulation.

## Branch Naming Strategy

- Base: `feature/<task-slug>`
- If exists: `feature/<task-slug>-2`, `-3`, etc.

### Task Name Requirements

**IMPORTANT:** Task names must contain English letters (a-z) or numbers (0-9).

- Use English names only: `add-oauth2-login`, `fix-login-bug`, `setup-dev-env`
- Chinese or other non-ASCII characters are NOT supported and will cause an error
- Special characters will be converted to hyphens

**Good examples:**
- `add-user-auth` → `feature/add-user-auth`
- `fix API endpoint` → `feature/fix-api-endpoint`
- `Setup Project v2` → `feature/setup-project-v2`

**Bad examples (will fail):**
- `搭建开发环境` → Error: no English letters
- `添加用户认证` → Error: no English letters

## Parent Branch Tracking

When creating a worktree, the system records which branch you started from (parent branch). This solves the common problem where a PR from branch B (created from branch A) incorrectly targets `main` instead of branch A.

### How it works:

1. **Creation**: `create-worktree.js` captures the current branch as `PARENT_BRANCH`
2. **Storage**: `setup-tmux.js` writes parent branch to `.tmux-worktree/progress.md`
3. **Cleanup**: `cleanup.js` checks merge status against the parent branch (not always main)

### Progress.md includes:

```markdown
## Branch Info

- **Current Branch**: feature/my-task
- **Parent Branch**: feature/parent-task <-- The branch you started from
- **Main Branch**: master

## Merge Target

应当合并到: **feature/parent-task** (父分支)

> ⚠️ **重要**: 创建 PR 时请确认目标分支是 **feature/parent-task** 而不是 master!
```

### Creating PRs with correct target:

When ready to create a PR, check the parent branch in `.tmux-worktree/progress.md`, then:

```bash
# Get parent branch
git config --get "branch.$(git branch --show-current).parent"

# Or read from progress.md
grep "Parent Branch" .tmux-worktree/progress.md

# Create PR with gh CLI (example)
gh pr create --base "<parent-branch>" --title "..."
```

## Error Handling

- Not in git repo → Clear error message
- Worktree path exists → Uses timestamp suffix
- Tmux not running → Creates session automatically
- AI tool not found → Lists available tools
- Config file missing → Automatically created from template

## Quick Reference

### Commands

```bash
# Query available AI tools
${SKILL_ROOT}/bin/tmux-worktree query-config
# Output: { "default_ai": "...", "ai_tools": {...} }

# Create a new worktree
${SKILL_ROOT}/bin/tmux-worktree create "<task-name>"
# Output: WORKTREE_PATH=.worktrees/<task-slug>
#         BRANCH_NAME=feature/<task-slug>
#         PARENT_BRANCH=feature/parent-branch  <-- The branch you started from
#         MAIN_BRANCH=master

# Setup tmux session with AI
${SKILL_ROOT}/bin/tmux-worktree setup "<worktree-path>" "<task-name>" [ai-tool] "<structured-prompt>"
# Output: SESSION=worktree-session WINDOW=<task-slug> AI_TOOL=<tool>
# Note: Script saves prompt to .tmux-worktree/prompt.md
# Note: Script invokes AI via cat .tmux-worktree/prompt.md | ai-tool

# List active worktrees
${SKILL_ROOT}/bin/tmux-worktree list

# Cleanup completed worktrees (interactive)
${SKILL_ROOT}/bin/tmux-worktree cleanup
```

### Interactive AI Selection Format

```javascript
{
  "questions": [{
    "question": "选择AI工具用于此任务：",
    "header": "AI工具",
    "options": aiTools.map(tool => ({
      "label": tool.name,
      "description": tool.description
    })),
    "multiSelect": false
  }]
}
```

### Example Session

```bash
# 1. Create the worktree
${SKILL_ROOT}/bin/tmux-worktree create "add OAuth2 login"
# Output: WORKTREE_PATH=.worktrees/add-oauth2-login
#         BRANCH_NAME=feature/add-oauth2-login

# 2. Setup tmux with AI
${SKILL_ROOT}/bin/tmux-worktree setup ".worktrees/add-oauth2-login" "add-oauth2-login" "claude" "Add OAuth2 login"
# Output: SESSION=worktree-session WINDOW=add-oauth2-login AI_TOOL=claude

# 3. (Later) Check status
${SKILL_ROOT}/bin/tmux-worktree list

# 4. (Later) Cleanup
${SKILL_ROOT}/bin/tmux-worktree cleanup
```

## See Also

- Usage examples: Run `tmux-worktree --help` for usage information
