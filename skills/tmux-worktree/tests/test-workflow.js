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
