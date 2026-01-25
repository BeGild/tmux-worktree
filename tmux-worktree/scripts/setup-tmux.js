#!/usr/bin/env node
import { execSync } from 'child_process';
import { existsSync, readFileSync, statSync } from 'fs';
import { homedir } from 'os';

// Handle both direct calls and bin wrapper calls
const COMMAND_NAMES = ['create', 'setup', 'list', 'cleanup'];
const ARGV_OFFSET = COMMAND_NAMES.includes(process.argv[2]) ? 1 : 0;

const WORKTREE_PATH = process.argv[2 + ARGV_OFFSET];
const TASK_NAME = process.argv[3 + ARGV_OFFSET];
const PROMPT = process.argv.slice(4 + ARGV_OFFSET).join(' ');

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
try {
  if (!statSync(WORKTREE_PATH).isDirectory()) {
    console.error(`Error: worktree path is not a directory: ${WORKTREE_PATH}`);
    process.exit(1);
  }
} catch {
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
