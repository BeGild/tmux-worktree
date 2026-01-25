#!/usr/bin/env node
import { execSync } from 'child_process';
import { existsSync, readFileSync } from 'fs';

try {
  execSync('git rev-parse --git-dir', { stdio: 'pipe' });
} catch {
  console.error('Error: Not in a git repository');
  process.exit(1);
}

// Header
const row = (a, b, c, d) => `${a.padEnd(30)} ${b.padEnd(20)} ${c.padEnd(5)} ${d}`;
console.log(row('Branch', 'Worktree', 'Changes', 'Result'));
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

  // Check RESULT.md
  let result = '-';
  try {
    const resultPath = `${path}/RESULT.md`;
    const content = readFileSync(resultPath, 'utf-8');
    const firstLine = content.split('\n')[0].slice(0, 50);
    result = `✓ ${firstLine}`;
  } catch {}

  console.log(row(displayBranch, wtShort, String(status), result));
}
