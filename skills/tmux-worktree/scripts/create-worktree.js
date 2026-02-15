#!/usr/bin/env node
import { execSync } from 'child_process';
import { mkdirSync, existsSync } from 'fs';
import { ensureConfig } from './lib/config.js';

// Handle both direct calls and bin wrapper calls
// Direct: node create-worktree.js "task" → argv[2] = task
// Wrapper: node bin/tmux-worktree create "task" → argv[2] = "create", argv[3] = task
const COMMAND_NAMES = ['create', 'setup', 'list', 'cleanup', 'query-config'];
const ARGV_OFFSET = COMMAND_NAMES.includes(process.argv[2]) ? 1 : 0;

const TASK_NAME = process.argv[2 + ARGV_OFFSET];
const BASE_DIR = process.argv[3 + ARGV_OFFSET] || '.worktrees';

// Ensure config exists
ensureConfig();

// Validation
if (!TASK_NAME) {
  console.error('Error: Task name is required');
  process.exit(1);
}

// Validate BASE_DIR to prevent command injection
if (!BASE_DIR.match(/^[a-zA-Z0-9._/-]+$/)) {
  console.error('Error: Invalid BASE_DIR - contains dangerous characters');
  process.exit(1);
}

try {
  execSync('git rev-parse --git-dir', { stdio: 'pipe' });
} catch {
  console.error('Error: Not in a git repository');
  process.exit(1);
}

// Get parent branch (current branch when worktree is created)
let PARENT_BRANCH = '';
try {
  PARENT_BRANCH = execSync('git branch --show-current', { encoding: 'utf-8' }).trim();
} catch {}

// Get main/master branch name for reference
let MAIN_BRANCH = 'main';
try {
  MAIN_BRANCH = execSync('git symbolic-ref refs/remotes/origin/HEAD', { encoding: 'utf-8' })
    .replace('refs/remotes/origin/', '').trim();
} catch {
  try {
    execSync('git show-ref --verify --quiet refs/heads/main', { stdio: 'pipe' });
  } catch {
    MAIN_BRANCH = 'master';
  }
}

// Slugify - match shell behavior exactly (underscores become hyphens)
let SLUG = TASK_NAME.toLowerCase().replace(/[^a-z0-9]/g, '-').replace(/-+/g, '-').replace(/^-+|-+$/g, '');

// If slug is empty (e.g., Chinese characters only), return error
if (!SLUG) {
  console.error('Error: Task name must contain English letters or numbers.');
  console.error('提示: 任务名称必须包含英文字母或数字，不支持纯中文命名。');
  console.error('Example: "setup-dev-env" instead of "搭建开发环境"');
  process.exit(1);
}

// Get existing branches
const existing = execSync('git branch', { encoding: 'utf-8' })
  .split('\n')
  .map(l => l.replace(/^\*?\s*/, '').trim())
  .filter(Boolean);

const BASE_BRANCH = `feature/${SLUG}`;

// Find unique branch name
let BRANCH_NAME = BASE_BRANCH;
if (existing.includes(BASE_BRANCH)) {
  const nums = existing
    .filter(b => b.match(new RegExp(`^${BASE_BRANCH}-([0-9]+)$`)))
    .map(b => parseInt(b.split('-').pop()))
    .filter(n => !isNaN(n));
  const next = nums.length ? Math.max(...nums) + 1 : 2;
  BRANCH_NAME = `${BASE_BRANCH}-${next}`;
}

// Create worktree
let WORKTREE_PATH = `${BASE_DIR}/${SLUG}`;
mkdirSync(BASE_DIR, { recursive: true });

// Check if worktree path already exists, add timestamp if needed
if (existsSync(WORKTREE_PATH)) {
  const now = new Date();
  const timestamp = now.getFullYear() +
    String(now.getMonth() + 1).padStart(2, '0') +
    String(now.getDate()).padStart(2, '0') + '-' +
    String(now.getHours()).padStart(2, '0') +
    String(now.getMinutes()).padStart(2, '0') +
    String(now.getSeconds()).padStart(2, '0');
  WORKTREE_PATH = `${BASE_DIR}/${SLUG}-${timestamp}`;
}

try {
  execSync(`git worktree add "${WORKTREE_PATH}" -b "${BRANCH_NAME}"`, { stdio: 'pipe' });
} catch (e) {
  console.error(`Error: Failed to create worktree at ${WORKTREE_PATH}`);
  console.error(e.stderr?.toString() || e.message);
  process.exit(1);
}

console.log(`WORKTREE_PATH=${WORKTREE_PATH}`);
console.log(`BRANCH_NAME=${BRANCH_NAME}`);
console.log(`PARENT_BRANCH=${PARENT_BRANCH}`);
console.log(`MAIN_BRANCH=${MAIN_BRANCH}`);
