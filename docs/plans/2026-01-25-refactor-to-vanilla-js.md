# Refactor tmux-worktree to Vanilla JavaScript Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Refactor tmux-worktree from shell scripts to vanilla JavaScript (no external dependencies).

**Architecture:** Each `.sh` file becomes a `.js` file. Helper functions inline where needed. Simple, direct.

**Tech Stack:** Node.js (ES modules), vanilla JavaScript

---

## Directory Structure

```
tmux-worktree/
├── package.json
├── bin/tmux-worktree
├── scripts/
│   ├── create-worktree.js
│   ├── setup-tmux.js
│   ├── list-worktrees.js
│   └── cleanup.js
├── assets/config-template.yaml
├── references/CONFIG.md
├── references/EXAMPLES.md
├── tests/test-workflow.js
└── SKILL.md
```

---

## Task 1: Create package.json and bin entry

**Files:**
- Create: `package.json`
- Create: `bin/tmux-worktree`

**Step 1: Create package.json**

```json
{
  "name": "tmux-worktree",
  "version": "2.0.0",
  "type": "module",
  "bin": {
    "tmux-worktree": "./bin/tmux-worktree"
  }
}
```

**Step 2: Create bin/tmux-worktree**

```javascript
#!/usr/bin/env node
import { run } from '../scripts/index.js';

await run(process.argv.slice(2));
```

**Step 3: Make executable**

```bash
chmod +x bin/tmux-worktree
```

**Step 4: Commit**

```bash
git add package.json bin/tmux-worktree
git commit -m "feat: add package.json and CLI entry point"
```

---

## Task 2: Implement create-worktree.js

**Files:**
- Create: `scripts/create-worktree.js`
- Create: `scripts/index.js`

**Step 1: Create scripts/create-worktree.js**

```javascript
#!/usr/bin/env node
import { execSync } from 'child_process';
import { mkdirSync } from 'fs';

const TASK_NAME = process.argv[2];
const BASE_DIR = process.argv[3] || '.worktrees';

// Validation
if (!TASK_NAME) {
  console.error('Error: Task name is required');
  process.exit(1);
}

try {
  execSync('git rev-parse --git-dir', { stdio: 'pipe' });
} catch {
  console.error('Error: Not in a git repository');
  process.exit(1);
}

// Slugify
const SLUG = TASK_NAME.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '');
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

try {
  execSync(`git worktree add "${WORKTREE_PATH}" -b "${BRANCH_NAME}"`, { stdio: 'pipe' });
} catch (e) {
  console.error(`Error: Failed to create worktree at ${WORKTREE_PATH}`);
  process.exit(1);
}

console.log(`WORKTREE_PATH=${WORKTREE_PATH}`);
console.log(`BRANCH_NAME=${BRANCH_NAME}`);
```

**Step 2: Create scripts/index.js**

```javascript
#!/usr/bin/env node
export async function run(args) {
  const [cmd, ...rest] = args;
  const commands = {
    create: () => import('./create-worktree.js'),
    setup: () => import('./setup-tmux.js'),
    list: () => import('./list-worktrees.js'),
    cleanup: () => import('./cleanup.js'),
  };

  if (!commands[cmd]) {
    console.error(`Unknown command: ${cmd}`);
    console.error('Usage: tmux-worktree <create|setup|list|cleanup>');
    process.exit(1);
  }

  // Commands handle their own args via process.argv
  await commands[cmd]();
}
```

**Step 3: Test**

```bash
node bin/tmux-worktree create "test feature"
```

**Step 4: Commit**

```bash
git add scripts/create-worktree.js scripts/index.js
git commit -m "feat: implement create-worktree command"
```

---

## Task 3: Implement setup-tmux.js

**Files:**
- Create: `scripts/setup-tmux.js`

**Step 1: Create scripts/setup-tmux.js**

```javascript
#!/usr/bin/env node
import { execSync } from 'child_process';
import { existsSync, readFileSync } from 'fs';
import { homedir } from 'os';

const WORKTREE_PATH = process.argv[2];
const TASK_NAME = process.argv[3];
const PROMPT = process.argv.slice(4).join(' ');

// Validation
if (!WORKTREE_PATH || !TASK_NAME || !PROMPT) {
  console.error('Usage: tmux-worktree setup <worktree-path> <task-name> <prompt>');
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

// Load config
const CONFIG_PATH = `${process.env.XDG_CONFIG_HOME || `${homedir()}/.config`}/tmux-worktree/config.yaml`;

if (!existsSync(CONFIG_PATH)) {
  console.error(`Error: Config file not found at ${CONFIG_PATH}`);
  process.exit(1);
}

const config = readFileSync(CONFIG_PATH, 'utf-8');

// Parse ai_command (handle quotes)
const aiMatch = config.match(/^ai_command:\s*(.+)$/m);
let AI_COMMAND = aiMatch ? aiMatch[1].trim() : '';
if ((AI_COMMAND.startsWith('"') && AI_COMMAND.endsWith('"')) ||
    (AI_COMMAND.startsWith("'") && AI_COMMAND.endsWith("'"))) {
  AI_COMMAND = AI_COMMAND.slice(1, -1);
}

if (!AI_COMMAND) {
  console.error('Error: ai_command not found in config');
  process.exit(1);
}

// Parse result_prompt_suffix (multiline)
const suffixMatch = config.match(/result_prompt_suffix:\s*\|([\s\S]+?)(?=^\w+:|$)/m);
const RESULT_SUFFIX = suffixMatch ? suffixMatch[1].trim() : '';

const FULL_PROMPT = `${PROMPT}\n\n${RESULT_SUFFIX}`;

// Get session name
let SESSION_NAME = 'worktree-session';
if (process.env.TMUX) {
  try {
    SESSION_NAME = execSync('tmux display-message -p "#S"', { encoding: 'utf-8' }).trim();
  } catch {}
}

// Window name
const WINDOW_NAME = TASK_NAME.replace(/[^a-zA-Z0-9-]/g, '-').slice(0, 20);

// Create session/window
try {
  execSync(`tmux new-session -d -s "${SESSION_NAME}" -n "${WINDOW_NAME}" -c "${WORKTREE_PATH}"`, { stdio: 'pipe' });
} catch {
  execSync(`tmux new-window -t "${SESSION_NAME}" -n "${WINDOW_NAME}" -c "${WORKTREE_PATH}"`, { stdio: 'pipe' });
}

// Escape and send command
const ESCAPED_PROMPT = FULL_PROMPT.replace(/'/g, "'\\''");
const AI_CMD = AI_COMMAND.replace('{prompt}', ESCAPED_PROMPT);
execSync(`tmux send-keys -t "${SESSION_NAME}:${WINDOW_NAME}" "${AI_CMD}" C-m`, { stdio: 'pipe' });

console.log(`SESSION=${SESSION_NAME}`);
console.log(`WINDOW=${WINDOW_NAME}`);
```

**Step 2: Commit**

```bash
git add scripts/setup-tmux.js
git commit -m "feat: implement setup-tmux command"
```

---

## Task 4: Implement list-worktrees.js

**Files:**
- Create: `scripts/list-worktrees.js`

**Step 1: Create scripts/list-worktrees.js**

```javascript
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
```

**Step 2: Commit**

```bash
git add scripts/list-worktrees.js
git commit -m "feat: implement list-worktrees command"
```

---

## Task 5: Implement cleanup.js

**Files:**
- Create: `scripts/cleanup.js`

**Step 1: Create scripts/cleanup.js**

```javascript
#!/usr/bin/env node
import { execSync } from 'child_process';
import { createInterface } from 'readline';

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

for (const block of blocks) {
  let path = '', branch = '';
  for (const line of block.split('\n')) {
    if (line.startsWith('worktree ')) path = line.slice(9);
    if (line.startsWith('branch ')) branch = line.slice(7).replace('refs/heads/', '');
  }

  if (!path || path === MAIN_TOPLEVEL) continue;

  const displayBranch = branch || '(detached)';
  let reason = null;

  if (!branch) {
    reason = '(detached)';
  } else {
    // Check if merged
    try {
      const merged = execSync(`git branch --merged "${MAIN_BRANCH}" --format="%(refname:short)"`, { encoding: 'utf-8' });
      if (merged.split('\n').map(l => l.trim()).includes(branch)) {
        reason = `(merged to ${MAIN_BRANCH})`;
      }
    } catch {}

    if (!reason) {
      try {
        const commits = execSync(`git log ${MAIN_BRANCH}..${branch} --oneline`, { encoding: 'utf-8' });
        if (!commits.trim()) {
          reason = '(no unique commits)';
        }
      } catch {}
    }
  }

  if (reason) {
    candidates.push({ path, branch: displayBranch, reason });
  }
}

// Interactive cleanup
const rl = createInterface({ input: process.stdin, output: process.stdout });

const ask = (q) => new Promise(resolve => rl.question(q, resolve));

for (const c of candidates) {
  console.log(`Remove ${c.branch} ${c.reason}?`);
  console.log(`  Path: ${c.path}`);

  const ans = await ask('[y/N] ');
  if (ans === 'y' || ans === 'Y') {
    try {
      execSync(`git worktree remove --force "${c.path}"`, { stdio: 'pipe' });
      console.log(`✓ Removed: ${c.branch}`);
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
```

**Step 2: Commit**

```bash
git add scripts/cleanup.js
git commit -m "feat: implement cleanup command"
```

---

## Task 6: Update tests to JavaScript

**Files:**
- Create: `tests/test-workflow.js`

**Step 1: Create tests/test-workflow.js**

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

**Step 2: Run tests**

```bash
node tests/test-workflow.js
```

**Step 3: Commit**

```bash
git add tests/test-workflow.js
git commit -m "test: convert tests to JavaScript"
```

---

## Task 7: Update SKILL.md

**Files:**
- Modify: `SKILL.md`

**Step 1: Update command examples in SKILL.md**

Change shell script references to JavaScript CLI:
```markdown
# Old:
./scripts/create-worktree.sh "add OAuth2"

# New:
tmux-worktree create "add OAuth2"
```

**Step 2: Commit**

```bash
git add SKILL.md
git commit -m "docs: update SKILL.md for JavaScript CLI"
```

---

## Task 8: Final RESULT.md

**Files:**
- Create: `RESULT.md`

**Step 1: Create RESULT.md**

```markdown
# tmux-worktree JavaScript Refactor - Summary

## Changes

- Converted 4 shell scripts to JavaScript
- Added package.json with ES modules
- Added bin/tmux-worktree CLI entry point
- Zero external dependencies

## Files

- `package.json` - ES modules config
- `bin/tmux-worktree` - CLI entry point
- `scripts/create-worktree.js` - Was .sh
- `scripts/setup-tmux.js` - Was .sh
- `scripts/list-worktrees.js` - Was .sh
- `scripts/cleanup.js` - Was .sh
- `scripts/index.js` - Command router
- `tests/test-workflow.js` - JS tests

## Testing

All tests pass. No dependencies.

## Next Steps

- Optional: Add to npm for easy install
- Optional: Add more tests
```

**Step 2: Commit**

```bash
git add RESULT.md
git commit -m "docs: add RESULT.md"
```

---

## Summary

**Total tasks: 8**
**Files created: 8**
**Files modified: 2**
**Dependencies: 0**

Simple. Direct. Done.
