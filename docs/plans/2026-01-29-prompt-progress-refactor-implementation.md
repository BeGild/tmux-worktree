# Prompt & Progress Refactor Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 将 RESULT.md 重构为 prompt.md 和 progress.md，实现提示词持久化和可追溯的进度跟踪。

**Architecture:**
1. setup 脚本自动保存 prompt 到 `.tmux-worktree/prompt.md`，生成空的 `progress.md` 模板
2. 通过 `cat .tmux-worktree/prompt.md | ai-tool` 驱动 AI 工具（不再使用 {prompt} 占位符）
3. stop hook 每次返回完整 progress.md 模板，确保 AI 按正确格式更新
4. list 命令读取 progress.md 显示状态

**Tech Stack:** Node.js (setup/list scripts), Python (stop hook), Git, tmux

---

## Task 1: 更新 .gitignore

**Files:**
- Modify: `.gitignore`

**Step 1: 更新 .gitignore，移除 RESULT.md，添加 .tmux-worktree/**

```bash
# 编辑 .gitignore，将内容更新为：
# Worktrees
.worktrees/

# Tmux-worktree task management
.tmux-worktree/
```

**Step 2: 验证变更**

```bash
cat .gitignore | grep -E "worktrees|tmux-worktree"
```

Expected output:
```
.worktrees/
.tmux-worktree/
```

**Step 3: 提交**

```bash
git add .gitignore
git commit -m "refactor: update .gitignore for prompt.md/progress.md

- Remove RESULT.md entry
- Add .tmux-worktree/ directory for prompt and progress tracking
"
```

---

## Task 2: 更新 CONFIG.md

**Files:**
- Modify: `skills/tmux-worktree/references/CONFIG.md`

**Step 1: 更新 ai_tools.command 说明**

找到 `ai_tools.command` 部分，将说明从使用 `{prompt}` 占位符改为通过 stdin 接收输入。

**完整的 CONFIG.md 内容：**

```markdown
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
```

**Step 2: 提交**

```bash
git add skills/tmux-worktree/references/CONFIG.md
git commit -m "docs: update CONFIG.md for stdin-based AI invocation

- Remove {prompt} placeholder documentation
- Document stdin-based invocation via cat prompt.md
- Add prompt.md and progress.md file descriptions
"
```

---

## Task 3: 更新 SKILL.md

**Files:**
- Modify: `skills/tmux-worktree/SKILL.md`

**Step 1: 在 Overview 部分添加新描述**

在 Overview 中找到：
```markdown
- Automatic result capture via RESULT.md files
```

替换为：
```markdown
- **Prompt persistence via `.tmux-worktree/prompt.md` for task traceability**
- **Progress tracking via `.tmux-worktree/progress.md`**
```

**Step 2: 在 Overview 后添加 Prompt Template 章节**

在 `## Overview` 后面，`## When to Use` 之前，添加：

```markdown
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
```

**Step 3: 更新 Project Setup 部分**

找到 `### Project Setup (First Time Only)` 部分，更新 Required .gitignore entries：

```markdown
**Required .gitignore entries:**

```gitignore
# Worktrees
.worktrees/

# Tmux-worktree task management
.tmux-worktree/
```

**Verify with:** `cat .gitignore | grep -E "worktrees|tmux-worktree"`
```

**Step 4: 更新 Phase 1: CREATE 步骤**

找到 `### Phase 1: CREATE` 的 Step-by-step 部分，更新为：

```markdown
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
```

**Step 5: 更新 Phase 2: WORK 部分**

找到 `### Phase 2: WORK` 的 Key behaviors 部分，更新为：

```markdown
**Key behaviors:**

- All work stays in the worktree directory
- Branch is isolated from main/master
- AI tool runs in dedicated tmux window
- **`.tmux-worktree/prompt.md` contains the original task definition**
- **`.tmux-worktree/progress.md` tracks progress and final results**
```

**Step 6: 更新 Phase 3: CLEANUP 部分**

找到 `### Phase 3: CLEANUP` 的 Step-by-step 部分，更新第 2 步：

```markdown
2. **Review progress:** `cat .worktrees/<task-name>/.tmux-worktree/progress.md` (if exists)
   - Offer to show progress.md contents for tasks being removed
```

更新 AI Responsibility 部分：

```markdown
**AI Responsibility:**

- ALWAYS run `list` before cleanup to show current state
- **Now shows Status from progress.md (In Progress/Completed/Blocked/Abandoned)**
- Offer to display progress.md before removing worktrees
- Guide user through interactive cleanup prompts
- Confirm removal was successful
```

**Step 7: 更新 Quick Reference 的 Commands 部分**

找到 `### Commands` 部分，更新 setup 命令说明：

```markdown
# Setup tmux session with AI
${SKILL_ROOT}/bin/tmux-worktree setup "<worktree-path>" "<task-name>" [ai-tool] "<structured-prompt>"
# Output: SESSION=worktree-session WINDOW=<task-slug> AI_TOOL=<tool>
# Note: Script saves prompt to .tmux-worktree/prompt.md
# Note: Script invokes AI via cat .tmux-worktree/prompt.md | ai-tool
```

**Step 8: 移除旧的 RESULT.md 相关引用**

搜索整个 SKILL.md，移除所有 `RESULT.md` 的引用（已被上面的更新覆盖）。

**Step 9: 提交**

```bash
git add skills/tmux-worktree/SKILL.md
git commit -m "docs: update SKILL.md for prompt.md/progress.md refactor

- Add Prompt Template section for Main Agent
- Update Project Setup .gitignore entries
- Update CREATE phase with new flow
- Update WORK phase with new file descriptions
- Update CLEANUP phase to read progress.md
- Update Quick Reference command documentation
"
```

---

## Task 4: 修改 setup.js

**Files:**
- Modify: `skills/tmux-worktree/scripts/setup-tmux.js`

**Step 1: 添加 fs 导入（如果不存在）**

确保文件顶部有：
```javascript
import { existsSync, mkdirSync, writeFileSync } from 'fs';
import { dirname } from 'path';
```

**Step 2: 在验证 AI tool 配置后，添加 .tmux-worktree 目录创建和文件写入代码**

找到这段代码（大约在第 80 行）：
```javascript
if (!aiConfig || !aiConfig.command) {
  console.error(`Error: AI tool "${AI_TOOL}" not found or missing "command" field`);
  process.exit(1);
}
```

在这段代码后面，添加：

```javascript
// ========== Create .tmux-worktree directory and write files ==========
const TMUX_DIR = `${WORKTREE_PATH}/.tmux-worktree`;

try {
  // Create directory if not exists
  if (!existsSync(TMUX_DIR)) {
    mkdirSync(TMUX_DIR, { recursive: true });
  }

  // Write prompt.md
  const PROMPT_FILE = `${TMUX_DIR}/prompt.md`;
  writeFileSync(PROMPT_FILE, PROMPT, 'utf-8');

  // Generate progress.md empty template
  const PROGRESS_FILE = `${TMUX_DIR}/progress.md`;
  const timestamp = new Date().toISOString();
  const progressTemplate = `# Task Progress

## Status
**In Progress** | Completed | Blocked | Abandoned

## Progress Log

### [${timestamp}] 任务启动
- 阅读 .tmux-worktree/prompt.md 了解任务目标
- 开始工作...

### [添加更多里程碑...]
---

## Final Summary

### Overview
{描述你做了什么}

### Changes Made
{总结实现的更改}

### Files Modified
{git 状态将自动填充到这里}

### Testing
{描述测试过程和结果}

### Blockers / Issues
{如果状态是 Blocked，描述问题。否则写 None}

### Next Steps
{描述接下来需要做什么}

### Cleanup Recommendation
选择一个并说明:
- **Ready to merge** → 可以合并到主分支
- **Continue working** → 保留 worktree 继续工作
- **Cleanup recommended** → 可以安全删除 worktree
- **Needs review** → 清理前需要人工审查

---
_Updated: ${timestamp}_
`;
  writeFileSync(PROGRESS_FILE, progressTemplate, 'utf-8');

} catch (err) {
  console.error(`Error: failed to create .tmux-worktree files: ${err.message}`);
  process.exit(1);
}
// ========== End of .tmux-worktree setup ==========
```

**Step 3: 修改 AI 调用方式**

找到这段代码（大约在第 103-106 行）：
```javascript
// 转义并发送命令
const ESCAPED_PROMPT = PROMPT.replace(/'/g, "'\\''");
const AI_CMD = aiConfig.command.replace('{prompt}', ESCAPED_PROMPT);
execSync(`tmux send-keys -t "${SESSION_NAME}:${WINDOW_NAME}" "${AI_CMD}" C-m`, { stdio: 'pipe' });
```

替换为：
```javascript
// ========== Invoke AI via cat prompt.md ==========
const PROMPT_FILE = `${TMUX_DIR}/prompt.md`;
const AI_CMD = `cat ${PROMPT_FILE} | ${aiConfig.command}`;
execSync(`tmux send-keys -t "${SESSION_NAME}:${WINDOW_NAME}" "${AI_CMD}" C-m`, { stdio: 'pipe' });
// ========== End of AI invocation ==========
```

**Step 4: 移除旧注释**

找到并移除这行（大约在第 83 行）：
```javascript
// RESULT.md is now auto-generated by SessionStop hook
```

**Step 5: 验证语法**

```bash
node -c skills/tmux-worktree/scripts/setup-tmux.js
```

Expected: 无输出（语法正确）

**Step 6: 提交**

```bash
git add skills/tmux-worktree/scripts/setup-tmux.js
git commit -m "refactor: setup.js saves prompt.md and generates progress.md

- Create .tmux-worktree/ directory
- Save received PROMPT to prompt.md
- Generate empty progress.md template
- Change AI invocation to use cat pipe instead of {prompt} placeholder
- Remove RESULT.md comment
"
```

---

## Task 5: 修改 session-stop.py

**Files:**
- Modify: `hooks/session-stop.py`

**Step 1: 更新文件头部注释**

将文件开头的注释更新为：
```python
#!/usr/bin/env python3
"""
Stop hook for tmux-worktree plugin
每次 stop 时返回完整的 progress.md 模板，确保 AI 按正确格式更新

Best practices from:
https://gist.github.com/alexfazio/653c5164d726987569ee8229a19f451f
"""
```

**Step 2: 添加 extract_objective 函数**

在 `extract_status` 函数后面添加：

```python
def extract_objective(content):
    """从 prompt.md 中提取任务目标（用于上下文提示）"""
    if "## Objective" not in content:
        return ""

    obj_section = content.split("## Objective")[1].split("##")[0]
    return obj_section.strip()[:200]  # 取前200字符
```

**Step 3: 添加 generate_progress_template 函数**

在 `has_uncommitted_changes` 函数后面添加：

```python
def generate_progress_template(git_info):
    """生成 progress.md 模板（每次 stop 都返回）"""
    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')

    return f"""# Task Progress

## Status
**In Progress** | Completed | Blocked | Abandoned

## Progress Log

### [添加已有的 Progress Log...]

---

## Final Summary

### Overview
{{描述你做了什么}}

### Changes Made
{{总结实现的更改}}

### Files Modified
{git_info}

### Testing
{{描述测试过程和结果}}

### Blockers / Issues
{{如果状态是 Blocked，描述问题。否则写 None}}

### Next Steps
{{描述接下来需要做什么}}

### Cleanup Recommendation
选择一个并说明:
- **Ready to merge** → 可以合并到主分支
- **Continue working** → 保留 worktree 继续工作
- **Cleanup recommended** → 可以安全删除 worktree
- **Needs review** → 清理前需要人工审查

---
_Updated: {timestamp}_
"""
```

**Step 4: 更新 main 函数中的文件路径**

找到 `result_file` 的定义（大约在第 80 行），替换为：

```python
        # ========== New file paths ==========
        tmux_dir = os.path.join(current_dir, ".tmux-worktree")
        progress_file = os.path.join(tmux_dir, "progress.md")
        prompt_file = os.path.join(tmux_dir, "prompt.md")
        # ========== End of file paths ==========
```

**Step 5: 更新检查 progress.md 的逻辑**

找到 `if os.path.exists(result_file):`（大约在第 82 行），将整个代码块更新为：

```python
        # Check progress.md
        if os.path.exists(progress_file):
            with open(progress_file, 'r', encoding='utf-8') as f:
                content = f.read()
                status = extract_status(content)

                # 方案B: 停止条件
                if status == "Completed":
                    if not has_uncommitted_changes():
                        sys.exit(0)  # 允许停止
                    else:
                        # 读取 prompt.md 获取上下文
                        objective = ""
                        if os.path.exists(prompt_file):
                            with open(prompt_file, 'r', encoding='utf-8') as pf:
                                objective = extract_objective(pf.read())

                        output = {
                            "decision": "block",
                            "reason": f"## 任务已完成但有未提交的文件\n\n**任务目标**: {objective}\n\n请先提交你的工作成果，然后再停止。"
                        }
                        print(json.dumps(output, ensure_ascii=False, indent=2))
                        sys.exit(0)

                elif status == "Blocked":
                    sys.exit(0)

                elif status == "Abandoned":
                    sys.exit(0)

                elif status == "In Progress":
                    # 读取 prompt.md 获取上下文
                    objective = ""
                    if os.path.exists(prompt_file):
                        with open(prompt_file, 'r', encoding='utf-8') as pf:
                            objective = extract_objective(pf.read())

                    # 获取 git 信息
                    untracked = run_git(["git", "ls-files", "--others", "--exclude-standard"])
                    modified = run_git(["git", "diff", "--name-only"])
                    staged = run_git(["git", "diff", "--cached", "--name-only"])
                    current_branch = run_git(["git", "rev-parse", "--abbrev-ref", "HEAD"])

                    files = []
                    if untracked:
                        files.extend([f"  - [未跟踪] {f}" for f in untracked.split('\n') if f])
                    if modified:
                        files.extend([f"  - [已修改] {f}" for f in modified.split('\n') if f])
                    if staged:
                        files.extend([f"  - [已暂存] {f}" for f in staged.split('\n') if f])
                    git_info = "\n".join(files) if files else "  (无)"

                    # 每次都返回完整模板
                    template = generate_progress_template(git_info)
                    output = {
                        "decision": "block",
                        "reason": f"## 任务还在进行中\n\n**当前分支**: `{current_branch}`\n\n**任务目标**: {objective}\n\n**当前 Status 是 In Progress**，请继续完成任务。\n\n如果任务已完成，请更新 progress.md：\n\n```markdown\n{template}\n```"
                    }
                    print(json.dumps(output, ensure_ascii=False, indent=2))
                    sys.exit(0)
```

**Step 6: 更新 progress.md 不存在时的处理**

找到生成 `result_content` 的代码块（大约在第 118-180 行），替换为：

```python
        # progress.md 不存在的情况，获取 git 信息并生成初始模板
        untracked_files = run_git(["git", "ls-files", "--others", "--exclude-standard"])
        modified_files = run_git(["git", "diff", "--name-only"])
        staged_files = run_git(["git", "diff", "--cached", "--name-only"])
        current_branch = run_git(["git", "rev-parse", "--abbrevref", "HEAD"])

        files = []
        if untracked_files:
            files.extend([f"  - [未跟踪] {f}" for f in untracked_files.split('\n') if f])
        if modified_files:
            files.extend([f"  - [已修改] {f}" for f in modified_files.split('\n') if f])
        if staged_files:
            files.extend([f"  - [已暂存] {f}" for f in staged_files.split('\n') if f])
        git_info = "\n".join(files) if files else "  (无)"

        template = generate_progress_template(git_info)

        output = {
            "decision": "block",
            "reason": f"## 请创建并填写 progress.md\n\n请创建 `.tmux-worktree/progress.md` 并填写以下模板：\n\n```markdown\n{template}\n```"
        }

        print(json.dumps(output, ensure_ascii=False, indent=2))
        sys.exit(0)
```

**Step 7: 移除旧的 INSTRUCTION 常量**

删除或注释掉旧的 `INSTRUCTION` 常量定义（如果存在）。

**Step 8: 验证语法**

```bash
python3 -m py_compile hooks/session-stop.py
```

Expected: 无输出（语法正确）

**Step 9: 提交**

```bash
git add hooks/session-stop.py
git commit -m "refactor: session-stop.py uses progress.md and prompt.md

- Update file paths to .tmux-worktree/ directory
- Add extract_objective function to read task context from prompt.md
- Add generate_progress_template function (returns full template each time)
- Update status checking logic to read progress.md
- Return full template with prompt.md context when blocking
- Remove old RESULT.md handling
"
```

---

## Task 6: 修改 list.js

**Files:**
- Modify: `skills/tmux-worktree/scripts/list-worktrees.js`

**Step 1: 更新 Header**

找到 Header 定义（大约在第 17-18 行），更新为：

```javascript
const row = (a, b, c, d) => `${a.padEnd(30)} ${b.padEnd(20)} ${c.padEnd(8)} ${d}`;
console.log(row('Branch', 'Worktree', 'Changes', 'Status'));
console.log(row('-------', '-------', '------', '------'));
```

**Step 2: 更新检查 RESULT.md 的逻辑**

找到 `// Check RESULT.md` 部分（大约在第 43-50 行），替换为：

```javascript
  // Check progress.md
  let progressStatus = '-';
  try {
    const progressPath = `${path}/.tmux-worktree/progress.md`;
    const content = readFileSync(progressPath, 'utf-8');

    // 提取 Status 字段
    const statusMatch = content.match(/## Status\s+\*\*(In Progress|Completed|Blocked|Abandoned)\*\*/);
    if (statusMatch) {
      progressStatus = statusMatch[1];
    } else {
      progressStatus = 'Unknown';
    }
  } catch {
    // progress.md 不存在
    progressStatus = '-';
  }

  console.log(row(displayBranch, wtShort, String(status), progressStatus));
```

**Step 3: 验证语法**

```bash
node -c skills/tmux-worktree/scripts/list-worktrees.js
```

Expected: 无输出（语法正确）

**Step 4: 提交**

```bash
git add skills/tmux-worktree/scripts/list-worktrees.js
git commit -m "refactor: list.js reads progress.md for status display

- Update header to show Status instead of Result
- Read .tmux-worktree/progress.md instead of RESULT.md
- Extract Status field using regex for display
- Show In Progress/Completed/Blocked/Abandoned/Unknown/-
"
```

---

## Task 7: 测试完整流程

**Files:**
- Test: Manual testing in a git repository

**Step 1: 确保 .gitignore 已更新**

```bash
cat .gitignore | grep -E "worktrees|tmux-worktree"
```

Expected output:
```
.worktrees/
.tmux-worktree/
```

**Step 2: 测试 create 和 setup**

```bash
# 创建测试 worktree
./skills/tmux-worktree/bin/tmux-worktree create "test-prompt-progress"

# 查看 output 中的 WORKTREE_PATH 和 BRANCH_NAME
# 然后运行 setup（使用结构化 prompt）
./skills/tmux-worktree/bin/tmux-worktree setup ".worktrees/test-prompt-progress" "test-prompt-progress" "claude" "# Task: Test Prompt Progress

## Context
- **Branch**: feature/test-prompt-progress
- **Worktree**: .worktrees/test-prompt-progress

## Objective
测试 prompt.md 和 progress.md 功能是否正常工作。

## Original Request
测试新功能

## Constraints
- 工作目录限制在当前 worktree 内
- 完成后更新 .tmux-worktree/progress.md 记录结果

## Success Criteria
- prompt.md 被正确保存
- progress.md 模板被正确生成
"
```

**Step 3: 验证文件已创建**

```bash
ls -la .worktrees/test-prompt-progress/.tmux-worktree/
cat .worktrees/test-prompt-progress/.tmux-worktree/prompt.md
cat .worktrees/test-prompt-progress/.tmux-worktree/progress.md
```

Expected:
- `.tmux-worktree/` 目录存在
- `prompt.md` 包含上面传入的结构化 prompt
- `progress.md` 包含空模板

**Step 4: 测试 list 命令**

```bash
./skills/tmux-worktree/bin/tmux-worktree list
```

Expected output 包含 Status 列，显示 "In Progress" 或类似状态。

**Step 5: 测试 stop hook（手动模拟）**

创建测试脚本来验证 stop hook 逻辑：

```bash
cd .worktrees/test-prompt-progress

# 设置环境变量模拟 worktree 环境
export CLAUDE_PROJECT_DIR="$(pwd)"

# 模拟 stop hook 调用（需要准备 JSON 输入）
echo '{}' | python3 ../../hooks/session-stop.py
```

Expected: 输出包含 progress.md 模板的 JSON

**Step 6: 清理测试 worktree**

```bash
cd ../..
./skills/tmux-worktree/bin/tmux-worktree cleanup
```

按照提示删除测试 worktree。

**Step 7: 更新版本号**

```bash
# 更新 package.json 中的版本号
# 例如从 2.0.3 -> 2.1.0
```

**Step 8: 提交测试结果和版本更新**

```bash
# 如果有测试脚本或配置更新
git add .
git commit -m "chore: bump version to 2.1.0 and test prompt/progress refactor

- Test complete flow: create -> setup -> list -> cleanup
- Verify prompt.md and progress.md files are created correctly
- Verify list command shows status from progress.md
- Verify stop hook returns progress.md template
"
```

---

## Task 8: 更新 EXAMPLES.md（可选）

**Files:**
- Modify: `skills/tmux-worktree/references/EXAMPLES.md`

如果有 EXAMPLES.md 文件，更新其中的示例以反映新的 prompt 模板和工作流。

**Step 1: 添加使用 prompt 模板的示例**

**Step 2: 提交**

```bash
git add skills/tmux-worktree/references/EXAMPLES.md
git commit -m "docs: update EXAMPLES.md with prompt template usage"
```

---

## 总结

完成所有任务后：
1. `.gitignore` 已更新，不再追踪 `.tmux-worktree/` 目录
2. `CONFIG.md` 已更新，移除 `{prompt}` 占位符说明
3. `SKILL.md` 已更新，添加 Prompt Template 规范
4. `setup.js` 已修改，自动保存 prompt.md 和生成 progress.md
5. `session-stop.py` 已修改，读取 progress.md 和 prompt.md
6. `list.js` 已修改，显示 progress.md 的状态
7. 完整流程已测试通过

**关键变更：**
- setup 脚本接收结构化 prompt，自动保存到 `prompt.md`
- AI 通过 `cat prompt.md | ai-tool` 方式调用
- stop hook 每次返回完整 progress.md 模板
- list 命令读取 progress.md 显示状态
