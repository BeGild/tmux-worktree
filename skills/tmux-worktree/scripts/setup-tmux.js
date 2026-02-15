#!/usr/bin/env node
import { execSync } from 'child_process';
import { existsSync, statSync, mkdirSync, writeFileSync } from 'fs';
import { resolve } from 'path';
import { loadConfig } from './lib/config.js';

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
config = loadConfig();
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

// Convert to absolute path to avoid tmux cwd issues
const WORKTREE_ABS_PATH = resolve(WORKTREE_PATH);

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

// ========== Create .tmux-worktree directory and write files ==========
const TMUX_DIR = `${WORKTREE_ABS_PATH}/.tmux-worktree`;

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

  // Get parent/main branch from environment (or default)
  const PARENT_BRANCH = process.env.TMUX_WORKTREE_PARENT_BRANCH || '';
  const MAIN_BRANCH = process.env.TMUX_WORKTREE_MAIN_BRANCH || 'main';

  const mergeTarget = PARENT_BRANCH && PARENT_BRANCH !== MAIN_BRANCH
    ? `应当合并到: **${PARENT_BRANCH}** (父分支)\n备选: ${MAIN_BRANCH} (如果 ${PARENT_BRANCH} 已被合并)`
    : `应当合并到: **${MAIN_BRANCH}**`;

  const progressTemplate = `# Task Progress

## Status
**In Progress** | Waiting for User | Completed | Blocked | Abandoned

<!--
状态说明（选择加粗一个）:
- **In Progress**: 正在工作，需要继续执行任务（不能停止）
- **Waiting for User**: 需要用户决策、确认或输入才能继续（允许停止等待用户）
- **Completed**: 任务已完成（无未提交更改时允许停止）
- **Blocked**: 被外部因素阻塞，如依赖未就绪、API 问题等（允许停止）
- **Abandoned**: 任务已放弃（允许停止）
-->

## Branch Info
- **Current Branch**: {当前分支名}
- **Parent Branch**: ${PARENT_BRANCH || MAIN_BRANCH}
- **Main Branch**: ${MAIN_BRANCH}

## Merge Target
${mergeTarget}

> ⚠️ **重要**: 创建 PR 时请确认目标分支是 **${PARENT_BRANCH || MAIN_BRANCH}** 而不是 ${MAIN_BRANCH}!

## Progress Log

### [${timestamp}] 任务启动
- 阅读 .tmux-worktree/prompt.md 了解任务目标
- 父分支: ${PARENT_BRANCH || '未检测到 (可能是detached state)'}
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
- **Ready to merge** → 可以合并到 **${PARENT_BRANCH || MAIN_BRANCH}**
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

// 获取 session 名称
let SESSION_NAME = 'worktree-session';
if (process.env.TMUX) {
  try {
    SESSION_NAME = execSync('tmux display-message -p "#S"', { encoding: 'utf-8' }).trim();
  } catch {}
}

// 窗口名称
const WINDOW_NAME = TASK_NAME.replace(/[^a-zA-Z0-9-]/g, '-').slice(0, 20);

// Get parent branch from environment or default to main/master
// (Already read earlier for progress template; keep for later usage)
let PARENT_BRANCH = process.env.TMUX_WORKTREE_PARENT_BRANCH || '';
let MAIN_BRANCH = process.env.TMUX_WORKTREE_MAIN_BRANCH || 'main';

// 创建 session/window（不指定工作目录，后续通过 cd 切换）
try {
  execSync(`tmux new-session -d -s "${SESSION_NAME}" -n "${WINDOW_NAME}"`, { stdio: 'pipe' });
} catch {
  execSync(`tmux new-window -t "${SESSION_NAME}" -n "${WINDOW_NAME}"`, { stdio: 'pipe' });
}

// 等待 shell 完全初始化（修复偶现的 shell 命令执行失败问题）
execSync('sleep 0.5', { stdio: 'pipe' });

// ========== Switch to worktree directory and invoke AI ==========
// 先切换到工作目录，然后执行 AI 命令
const CD_CMD = `cd "${WORKTREE_ABS_PATH}"`;
const AI_CMD = `cat .tmux-worktree/prompt.md | ${aiConfig.command}`;
execSync(`tmux send-keys -t "${SESSION_NAME}:${WINDOW_NAME}" "${CD_CMD}" C-m`, { stdio: 'pipe' });
execSync(`tmux send-keys -t "${SESSION_NAME}:${WINDOW_NAME}" "${AI_CMD}" C-m`, { stdio: 'pipe' });
// ========== End of AI invocation ==========

console.log(`SESSION=${SESSION_NAME}`);
console.log(`WINDOW=${WINDOW_NAME}`);
console.log(`AI_TOOL=${AI_TOOL}`);
