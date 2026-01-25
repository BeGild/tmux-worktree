#!/usr/bin/env node
import { execSync } from 'child_process';
import { mkdirSync, existsSync } from 'fs';

// Handle both direct calls and bin wrapper calls
// Direct: node create-worktree.js "task" → argv[2] = task
// Wrapper: node bin/tmux-worktree create "task" → argv[2] = "create", argv[3] = task
const COMMAND_NAMES = ['create', 'setup', 'list', 'cleanup'];
const ARGV_OFFSET = COMMAND_NAMES.includes(process.argv[2]) ? 1 : 0;

const TASK_NAME = process.argv[2 + ARGV_OFFSET];
const BASE_DIR = process.argv[3 + ARGV_OFFSET] || '.worktrees';

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

// Slugify - match shell behavior exactly (underscores become hyphens)
const SLUG = TASK_NAME.toLowerCase().replace(/[^a-z0-9]/g, '-').replace(/-+/g, '-').replace(/^-+|-+$/g, '');
if (!SLUG) {
  console.error('Error: Task name results in empty slug');
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
