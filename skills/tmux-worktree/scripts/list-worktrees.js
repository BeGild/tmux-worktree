#!/usr/bin/env node
import { execSync } from 'child_process';
import { existsSync, readFileSync } from 'fs';
import { ensureConfig } from './lib/config.js';

// 确保配置存在（如果需要配置驱动的功能）
ensureConfig();

try {
  execSync('git rev-parse --git-dir', { stdio: 'pipe' });
} catch {
  console.error('Error: Not in a git repository');
  process.exit(1);
}

// Header
const row = (a, b, c, d) => `${a.padEnd(30)} ${b.padEnd(20)} ${c.padEnd(8)} ${d}`;
console.log(row('Branch', 'Worktree', 'Changes', 'Status'));
console.log(row('-------', '-------', '------', '------'));

const output = execSync('git worktree list --porcelain', { encoding: 'utf-8' });
const blocks = output.split('\n\n').filter(Boolean);

for (const block of blocks) {
  let path = '', branch = '';
  for (const line of block.split('\n')) {
    if (line.startsWith('worktree ')) path = line.slice(9);
    if (line.startsWith('branch ')) branch = line.slice(7).replace('refs/heads/', '');
  }

  if (!path) continue;

  const wtShort = path.split('/').pop();
  const displayBranch = branch || '(detached)';

  // Get status
  let status = 0;
  try {
    const statusOut = execSync('git status --short', { cwd: path, encoding: 'utf-8' });
    status = statusOut.split('\n').filter(Boolean).length;
  } catch {}

  // Check progress.md
  let progressStatus = '-';
  try {
    const progressPath = `${path}/.tmux-worktree/progress.md`;
    const content = readFileSync(progressPath, 'utf-8');

    // 提取 Status 字段
    const statusMatch = content.match(/## Status\s+\*\*(In Progress|Waiting for User|Completed|Blocked|Abandoned)\*\*/);
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
}
