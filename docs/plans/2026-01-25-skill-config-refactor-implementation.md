# SKILL 配置重构实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**目标:** 将 SKILL 文件与配置管理解耦，配置对 AI 完全不可见，所有配置相关操作由脚本处理。

**架构:** 新增 `query-config` 命令输出 JSON 格式的 AI 工具信息，创建共享的配置管理模块处理自动复制和加载，重构 SKILL.md 工作流使其调用脚本获取配置而非直接读取。

**技术栈:** Node.js (vanilla ES modules), JSON 配置文件

---

### Task 1: 创建配置管理模块

**文件:**
- 创建: `tmux-worktree/scripts/lib/config.js`

**实现代码:**

```javascript
#!/usr/bin/env node
import { readFileSync, existsSync, mkdirSync, copyFileSync } from 'fs';
import { homedir } from 'os';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const CONFIG_DIR = `${process.env.XDG_CONFIG_HOME || `${homedir()}/.config`}/tmux-worktree`;
const CONFIG_PATH = join(CONFIG_DIR, 'config.json');
const TEMPLATE_PATH = join(__dirname, '../assets/config-template.json');

/**
 * 确保配置文件存在，若不存在则从模板自动复制
 */
export function ensureConfig() {
  if (existsSync(CONFIG_PATH)) {
    return;
  }

  // 创建配置目录
  mkdirSync(CONFIG_DIR, { recursive: true });

  // 从模板复制配置
  copyFileSync(TEMPLATE_PATH, CONFIG_PATH);
}

/**
 * 加载配置文件
 * @returns {Object} 配置对象
 */
export function loadConfig() {
  ensureConfig();

  try {
    const content = readFileSync(CONFIG_PATH, 'utf-8');
    return JSON.parse(content);
  } catch (e) {
    console.error(`Error: Failed to parse config file at ${CONFIG_PATH}`);
    console.error(e.message);
    process.exit(1);
  }
}

/**
 * 获取 AI 工具列表（用于 query-config 命令）
 * @returns {Object} { default_ai, ai_tools: [{name, description}, ...] }
 */
export function getAiToolsInfo() {
  const config = loadConfig();
  const aiTools = Object.entries(config.ai_tools || {}).map(([name, tool]) => ({
    name,
    description: tool.description || name
  }));

  return {
    default_ai: config.default_ai || aiTools[0]?.name || null,
    ai_tools: aiTools
  };
}

export { CONFIG_PATH };
```

**Step 1: 创建 lib 目录**

```bash
mkdir -p tmux-worktree/scripts/lib
```

**Step 2: 写入配置模块文件**

将上述代码写入 `tmux-worktree/scripts/lib/config.js`。

**Step 3: Commit**

```bash
git add tmux-worktree/scripts/lib/config.js
git commit -m "feat: add shared config management module with auto-copy"
```

---

### Task 2: 创建 query-config 命令

**文件:**
- 创建: `tmux-worktree/scripts/query-config.js`

**实现代码:**

```javascript
#!/usr/bin/env node
import { getAiToolsInfo } from './lib/config.js';

const info = getAiToolsInfo();
console.log(JSON.stringify(info, null, 2));
```

**Step 1: 写入 query-config.js 文件**

将上述代码写入 `tmux-worktree/scripts/query-config.js`。

**Step 2: 测试命令**

```bash
cd /tmp && mkdir -p test-query && cd test-query && git init
node /path/to/worktree/tmux-worktree/scripts/query-config.js
```

预期输出:
```json
{
  "default_ai": "claude",
  "ai_tools": [
    {
      "name": "claude",
      "description": "Anthropic Claude AI assistant"
    }
  ]
}
```

**Step 3: Commit**

```bash
git add tmux-worktree/scripts/query-config.js
git commit -m "feat: add query-config command to output AI tools as JSON"
```

---

### Task 3: 更新 index.js 添加 query-config 命令

**文件:**
- 修改: `tmux-worktree/scripts/index.js`

**修改内容:**

```javascript
#!/usr/bin/env node
export async function run(args) {
  const [cmd, ...rest] = args;
  const commands = {
    create: () => import('./create-worktree.js'),
    setup: () => import('./setup-tmux.js'),
    list: () => import('./list-worktrees.js'),
    cleanup: () => import('./cleanup.js'),
    'query-config': () => import('./query-config.js'),  // 新增
  };

  if (!commands[cmd]) {
    console.error(`Unknown command: ${cmd}`);
    console.error('Usage: tmux-worktree <create|setup|list|cleanup|query-config>');
    process.exit(1);
  }

  // Commands handle their own args via process.argv
  await commands[cmd]();
}
```

**Step 1: 编辑 index.js**

更新 commands 对象和错误信息。

**Step 2: 测试 query-config 命令**

```bash
node tmux-worktree/scripts/index.js query-config
```

预期: JSON 输出包含 AI 工具信息。

**Step 3: Commit**

```bash
git add tmux-worktree/scripts/index.js
git commit -m "feat: register query-config command in index"
```

---

### Task 4: 更新 create-worktree.js 使用配置管理模块

**文件:**
- 修改: `tmux-worktree/scripts/create-worktree.js`

**当前问题:** create-worktree.js 不需要读取配置，但为了一致性和未来扩展，应该在启动时确保配置存在。

**修改内容:**

在文件顶部添加导入，在验证之前调用 ensureConfig：

```javascript
#!/usr/bin/env node
import { execSync } from 'child_process';
import { mkdirSync, existsSync } from 'fs';
import { ensureConfig } from './lib/config.js';  // 新增

// ... 现有代码 ...

// Validation 之前添加
ensureConfig();  // 新增

if (!TASK_NAME) {
  console.error('Error: Task name is required');
  process.exit(1);
}
```

**Step 1: 编辑 create-worktree.js**

添加导入和 ensureConfig 调用。

**Step 2: 测试 create 命令**

```bash
# 在测试 git 仓库中
node tmux-worktree/scripts/index.js create "test task"
```

预期: 正常创建 worktree，配置自动复制（如果不存在）。

**Step 3: Commit**

```bash
git add tmux-worktree/scripts/create-worktree.js
git commit -m "refactor: use shared config module in create-worktree"
```

---

### Task 5: 更新 setup-tmux.js 使用配置管理模块

**文件:**
- 修改: `tmux-worktree/scripts/setup-tmux.js`

**当前代码分析:**
- 手动处理配置路径: `process.env.XDG_CONFIG_HOME || ...`
- 手动读取和解析 JSON
- 手动处理配置不存在的情况

**新实现:**

```javascript
#!/usr/bin/env node
import { execSync } from 'child_process';
import { existsSync, statSync } from 'fs';
import { loadConfig, CONFIG_PATH } from './lib/config.js';  // 使用共享模块

// Handle both direct calls and bin wrapper calls
const COMMAND_NAMES = ['create', 'setup', 'list', 'cleanup', 'query-config'];
const ARGV_OFFSET = COMMAND_NAMES.includes(process.argv[2]) ? 1 : 0;

const WORKTREE_PATH = process.argv[2 + ARGV_OFFSET];
const TASK_NAME = process.argv[3 + ARGV_OFFSET];

// Parse optional ai-tool and prompt
let AI_TOOL = null;
let PROMPT = '';
let config = null;

const remainingArgs = process.argv.slice(4 + ARGV_OFFSET);

// 首先加载配置以检查参数是否为有效的 AI 工具
config = loadConfig();  // 使用共享模块
const availableTools = Object.keys(config.ai_tools || {});

// 检查第一个参数是否为有效的 AI 工具
if (remainingArgs.length > 0 && availableTools.includes(remainingArgs[0])) {
  AI_TOOL = remainingArgs[0];
  PROMPT = remainingArgs.slice(1).join(' ');
} else {
  PROMPT = remainingArgs.join(' ');
}

// Validation
if (!WORKTREE_PATH || !TASK_NAME || !PROMPT) {
  console.error('Usage: tmux-worktree setup <worktree-path> <task-name> [ai-tool] <prompt>');
  console.error('  If ai-tool is omitted, uses default_ai from config');
  process.exit(1);
}

try {
  execSync('command -v tmux', { stdio: 'pipe' });
} catch {
  console.error('Error: tmux not installed');
  process.exit(1);
}

if (!existsSync(WORKTREE_PATH)) {
  console.error(`Error: worktree path not found: ${WORKTREE_PATH}`);
  process.exit(1);
}
try {
  if (!statSync(WORKTREE_PATH).isDirectory()) {
    console.error(`Error: worktree path is not a directory: ${WORKTREE_PATH}`);
    process.exit(1);
  }
} catch {
  console.error(`Error: worktree path not found: ${WORKTREE_PATH}`);
  process.exit(1);
}

// 验证配置结构（loadConfig 已经确保配置存在并加载）
if (!config.ai_tools || Object.keys(config.ai_tools).length === 0) {
  console.error('Error: No AI tools defined in config');
  process.exit(1);
}

// 选择 AI 工具
if (!AI_TOOL) {
  AI_TOOL = config.default_ai || Object.keys(config.ai_tools)[0];
}

const aiConfig = config.ai_tools[AI_TOOL];
if (!aiConfig) {
  console.error(`Error: AI tool "${AI_TOOL}" not found in config`);
  console.error(`Available tools: ${Object.keys(config.ai_tools).join(', ')}`);
  process.exit(1);
}

if (!aiConfig.command) {
  console.error(`Error: AI tool "${AI_TOOL}" is missing "command" field`);
  process.exit(1);
}

// 获取结果后缀（工具特定或全局）
const RESULT_SUFFIX = aiConfig.result_prompt_suffix || config.result_prompt_suffix || '';

const FULL_PROMPT = `${PROMPT}\n\n${RESULT_SUFFIX}`;

// 获取 session 名称
let SESSION_NAME = 'worktree-session';
if (process.env.TMUX) {
  try {
    SESSION_NAME = execSync('tmux display-message -p "#S"', { encoding: 'utf-8' }).trim();
  } catch {}
}

// 窗口名称
const WINDOW_NAME = TASK_NAME.replace(/[^a-zA-Z0-9-]/g, '-').slice(0, 20);

// 创建 session/window
try {
  execSync(`tmux new-session -d -s "${SESSION_NAME}" -n "${WINDOW_NAME}" -c "${WORKTREE_PATH}"`, { stdio: 'pipe' });
} catch {
  execSync(`tmux new-window -t "${SESSION_NAME}" -n "${WINDOW_NAME}" -c "${WORKTREE_PATH}"`, { stdio: 'pipe' });
}

// 转义并发送命令
const ESCAPED_PROMPT = FULL_PROMPT.replace(/'/g, "'\\''");
const AI_CMD = aiConfig.command.replace('{prompt}', ESCAPED_PROMPT);
execSync(`tmux send-keys -t "${SESSION_NAME}:${WINDOW_NAME}" "${AI_CMD}" C-m`, { stdio: 'pipe' });

console.log(`SESSION=${SESSION_NAME}`);
console.log(`WINDOW=${WINDOW_NAME}`);
console.log(`AI_TOOL=${AI_TOOL}`);
```

**Step 1: 编辑 setup-tmux.js**

替换配置相关代码为使用共享模块。

**Step 2: 测试 setup 命令**

```bash
# 先创建一个 worktree
node tmux-worktree/scripts/index.js create "test setup"
# 然后测试 setup
node tmux-worktree/scripts/index.js setup .worktrees/test-setup "test setup" "Test prompt"
```

预期: 正常设置 tmux 会话，配置自动处理。

**Step 3: Commit**

```bash
git add tmux-worktree/scripts/setup-tmux.js
git commit -m "refactor: use shared config module in setup-tmux"
```

---

### Task 6: 更新 list-worktrees.js 使用配置管理模块

**文件:**
- 修改: `tmux-worktree/scripts/list-worktrees.js`

**修改内容:**

list-worktrees.js 不需要读取配置内容，但为了一致性，添加 ensureConfig 调用：

```javascript
#!/usr/bin/env node
import { execSync } from 'child_process';
import { ensureConfig } from './lib/config.js';  // 新增

// 确保配置存在（如果需要配置驱动的功能）
ensureConfig();  // 新增

// ... 现有代码保持不变 ...
```

**Step 1: 编辑 list-worktrees.js**

添加导入和 ensureConfig 调用。

**Step 2: 测试 list 命令**

```bash
node tmux-worktree/scripts/index.js list
```

预期: 正常列出 worktrees。

**Step 3: Commit**

```bash
git add tmux-worktree/scripts/list-worktrees.js
git commit -m "refactor: use shared config module in list-worktrees"
```

---

### Task 7: 更新 cleanup.js 使用配置管理模块

**文件:**
- 修改: `tmux-worktree/scripts/cleanup.js`

**修改内容:**

类似 list-worktrees.js，添加 ensureConfig 调用以保持一致性：

```javascript
#!/usr/bin/env node
import { execSync } from 'child_process';
import { ensureConfig } from './lib/config.js';  // 新增

// 确保配置存在
ensureConfig();  // 新增

// ... 现有代码保持不变 ...
```

**Step 1: 编辑 cleanup.js**

添加导入和 ensureConfig 调用。

**Step 2: 测试 cleanup 命令**

```bash
node tmux-worktree/scripts/index.js cleanup
```

预期: 正常执行 cleanup 交互式提示。

**Step 3: Commit**

```bash
git add tmux-worktree/scripts/cleanup.js
git commit -m "refactor: use shared config module in cleanup"
```

---

### Task 8: 重写 SKILL.md

**文件:**
- 修改: `tmux-worktree/SKILL.md`

**新 SKILL.md 内容:**

```markdown
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
3. **AI tool configured** - Run `tmux-worktree query-config` to check available tools

## Workflow

### 1. Create a New Worktree Session

When the user wants to start a new task:

**Step-by-step:**

1. Query available AI tools by running `tmux-worktree query-config`
2. **Interactive AI Selection:**
   - If only one AI tool is available, use it automatically
   - If multiple AI tools are available, use `AskUserQuestion` to let the user choose
3. Generate a task slug from the user's description
4. Run `tmux-worktree create "<task-name>"`
5. Parse output for `WORKTREE_PATH` and `BRANCH_NAME`
6. Run `tmux-worktree setup "<worktree-path>" "<task-name>" "<ai-tool>" "<prompt>"`
7. Inform the user the environment is ready

**Interactive AI Selection with AskUserQuestion:**

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

**Example:**

```bash
# Query available tools
tmux-worktree query-config
# Output: { "default_ai": "claude", "ai_tools": [...] }

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

## Error Handling

- Not in git repo → Clear error message
- Worktree path exists → Uses timestamp suffix
- Tmux not running → Creates session automatically
- AI tool not found → Lists available tools
- Config file missing → Automatically created from template

## See Also

- Usage examples: Run `tmux-worktree --help` for usage information
```

**Step 1: 备份并重写 SKILL.md**

```bash
cp tmux-worktree/SKILL.md tmux-worktree/SKILL.md.bak
```

写入上述新内容到 `tmux-worktree/SKILL.md`。

**Step 2: 验证 SKILL.md 格式**

确保 YAML frontmatter 正确，markdown 格式有效。

**Step 3: Commit**

```bash
git add tmux-worktree/SKILL.md
git commit -m "refactor: rewrite SKILL.md - config fully managed by scripts"
```

---

### Task 9: 更新测试

**文件:**
- 修改: `tmux-worktree/tests/test-workflow.js`

**修改内容:**

添加 query-config 命令的测试：

```javascript
#!/usr/bin/env node
import { execSync } from 'child_process';
import { mkdtempSync, rmSync, existsSync } from 'fs';
import { tmpdir } from 'os';
import { join } from 'path';
import { fileURLToPath } from 'url';
import { dirname } from 'path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const CLI = join(dirname(__dirname), 'bin', 'tmux-worktree');

console.log('=== tmux-worktree Test ===\n');

const TEMP_DIR = mkdtempSync(join(tmpdir(), 'tmux-test-'));
const ORIGINAL_DIR = process.cwd();

const cleanup = () => {
  process.chdir(ORIGINAL_DIR);
  rmSync(TEMP_DIR, { recursive: true, force: true });
};

process.on('exit', cleanup);
process.on('SIGINT', () => { cleanup(); process.exit(130); });

process.chdir(TEMP_DIR);
execSync('git init -q', { stdio: 'pipe' });
execSync('git config user.name "Test"', { stdio: 'pipe' });
execSync('git config user.email "test@test.com"', { stdio: 'pipe' });
execSync('echo "# test" > README.md', { stdio: 'pipe' });
execSync('git add . && git commit -q -m "init"', { stdio: 'pipe' });

// Test query-config
console.log('Test: Query config');
const queryOutput = execSync(`node ${CLI} query-config`, { encoding: 'utf-8' });
const queryResult = JSON.parse(queryOutput);

if (!queryResult.ai_tools || !Array.isArray(queryResult.ai_tools)) {
  console.error('✗ query-config output invalid');
  process.exit(1);
}

console.log(`✓ Config queried: ${queryResult.ai_tools.length} AI tools available\n`);

// Test create
console.log('Test: Create worktree');
const out = execSync(`node ${CLI} create "test feature"`, { encoding: 'utf-8' });

const worktreePath = out.match(/^WORKTREE_PATH=(.+)$/m)?.[1];
const branchName = out.match(/^BRANCH_NAME=(.+)$/m)?.[1];

if (!worktreePath || !existsSync(worktreePath)) {
  console.error('✗ Worktree not created');
  process.exit(1);
}

if (!branchName) {
  console.error('✗ Branch name missing');
  process.exit(1);
}

console.log(`✓ Created: ${branchName} at ${worktreePath}\n`);

console.log('=== All tests passed ===');
```

**Step 1: 编辑 test-workflow.js**

添加 query-config 测试。

**Step 2: 运行测试**

```bash
node tmux-worktree/tests/test-workflow.js
```

预期: 所有测试通过。

**Step 3: Commit**

```bash
git add tmux-worktree/tests/test-workflow.js
git commit -m "test: add query-config test to test suite"
```

---

### Task 10: 最终验证

**Step 1: 运行完整测试套件**

```bash
node tmux-worktree/tests/test-workflow.js
```

预期: 所有测试通过。

**Step 2: 手动验证 query-config**

```bash
tmux-worktree query-config
```

预期: 输出有效的 JSON 包含 AI 工具信息。

**Step 3: 验证配置自动复制**

```bash
# 移除现有配置
rm -f ~/.config/tmux-worktree/config.json
# 运行任意命令
tmux-worktree list
# 检查配置已创建
ls -l ~/.config/tmux-worktree/config.json
```

预期: 配置文件自动从模板复制。

**Step 4: 最终 Commit**

```bash
git add -A
git commit -m "chore: final verification complete"
```

---

## 完成

实现完成后，SKILL 文件将不再包含配置细节，所有配置操作由脚本统一处理。
