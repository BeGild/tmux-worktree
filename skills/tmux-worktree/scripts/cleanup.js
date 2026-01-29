#!/usr/bin/env node
import { execSync } from 'child_process';
import { createInterface } from 'readline';
import { readFileSync, existsSync } from 'fs';
import { ensureConfig } from './lib/config.js';

// 确保配置存在
ensureConfig();

try {
  execSync('git rev-parse --git-dir', { stdio: 'pipe' });
} catch {
  console.error('Error: Not in a git repository');
  process.exit(1);
}

// Get main branch
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

const MAIN_TOPLEVEL = execSync('git rev-parse --show-toplevel', { encoding: 'utf-8' }).trim();

const output = execSync('git worktree list --porcelain', { encoding: 'utf-8' });
const blocks = output.split('\n\n').filter(Boolean);

const candidates = [];

// Helper function to extract parent branch from progress.md
function getParentBranch(worktreePath) {
  const progressFile = `${worktreePath}/.tmux-worktree/progress.md`;
  if (!existsSync(progressFile)) {
    return null;
  }
  try {
    const content = readFileSync(progressFile, 'utf-8');
    const match = content.match(/\*\*Parent Branch\*\*:\s*(.+)/);
    if (match) {
      return match[1].trim();
    }
  } catch {}
  return null;
}

for (const block of blocks) {
  let path = '', branch = '';
  for (const line of block.split('\n')) {
    if (line.startsWith('worktree ')) path = line.slice(9);
    if (line.startsWith('branch ')) branch = line.slice(7).replace('refs/heads/', '');
  }

  if (!path || path === MAIN_TOPLEVEL) continue;

  const displayBranch = branch || '(detached)';
  let reason = null;

  // Get parent branch for this worktree
  const parentBranch = getParentBranch(path);
  const mergeTarget = parentBranch || MAIN_BRANCH;

  if (!branch) {
    reason = '(detached)';
  } else {
    // Check if merged to its parent branch (not always main)
    try {
      const merged = execSync(`git branch --merged "${mergeTarget}" --format="%(refname:short)"`, { encoding: 'utf-8' });
      if (merged.split('\n').map(l => l.trim()).includes(branch)) {
        reason = `(merged to ${mergeTarget})`;
      }
    } catch {}

    if (!reason) {
      try {
        const commits = execSync(`git log ${mergeTarget}..${branch} --oneline`, { encoding: 'utf-8' });
        if (!commits.trim()) {
          reason = `(no unique commits vs ${mergeTarget})`;
        }
      } catch {}
    }
  }

  if (reason) {
    candidates.push({ path, branch: displayBranch, reason, parentBranch });
  }
}

// Interactive cleanup
const rl = createInterface({ input: process.stdin, output: process.stdout });

const ask = (q) => new Promise(resolve => rl.question(q, resolve));

async function doCleanup() {
  for (const c of candidates) {
    console.log(`Remove ${c.branch} ${c.reason}?`);
    console.log(`  Path: ${c.path}`);
    if (c.parentBranch && c.parentBranch !== MAIN_BRANCH) {
      console.log(`  Parent: ${c.parentBranch} (merge target)`);
    }

    const ans = await ask('[y/N] ');
    if (ans === 'y' || ans === 'Y') {
      try {
        execSync(`git worktree remove --force "${c.path}"`, { stdio: 'pipe' });
        console.log(`[OK] Removed: ${c.branch}`);
      } catch {
        console.error(`Warning: Could not remove worktree`);
      }

      if (c.branch !== '(detached)') {
        try {
          execSync(`git branch -d "${c.branch}"`, { stdio: 'pipe' });
        } catch {}
      }
    } else {
      console.log(`Skipped: ${c.branch}`);
    }
    console.log();
  }

  rl.close();
}

doCleanup().catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
