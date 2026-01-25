#!/usr/bin/env node
import { execSync } from 'child_process';
import { existsSync, readFileSync, statSync } from 'fs';
import { homedir } from 'os';

// Handle both direct calls and bin wrapper calls
const COMMAND_NAMES = ['create', 'setup', 'list', 'cleanup'];
const ARGV_OFFSET = COMMAND_NAMES.includes(process.argv[2]) ? 1 : 0;

const WORKTREE_PATH = process.argv[2 + ARGV_OFFSET];
const TASK_NAME = process.argv[3 + ARGV_OFFSET];

// Parse optional ai-tool and prompt
let AI_TOOL = null;
let PROMPT = '';
let config = null;

const remainingArgs = process.argv.slice(4 + ARGV_OFFSET);

// First, try to load config to check if the arg is a valid AI tool
const CONFIG_PATH = `${process.env.XDG_CONFIG_HOME || `${homedir()}/.config`}/tmux-worktree/config.json`;
if (existsSync(CONFIG_PATH)) {
  try {
    config = JSON.parse(readFileSync(CONFIG_PATH, 'utf-8'));
    const availableTools = Object.keys(config.ai_tools || {});

    // Check if first arg is a valid AI tool
    if (remainingArgs.length > 0 && availableTools.includes(remainingArgs[0])) {
      AI_TOOL = remainingArgs[0];
      PROMPT = remainingArgs.slice(1).join(' ');
    } else {
      PROMPT = remainingArgs.join(' ');
    }
  } catch {
    PROMPT = remainingArgs.join(' ');
  }
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

// Load config (if not already loaded for arg parsing)
if (!config) {
  if (!existsSync(CONFIG_PATH)) {
    console.error(`Error: Config file not found at ${CONFIG_PATH}`);
    console.error('Create it from the template: cp ./assets/config-template.json ~/.config/tmux-worktree/config.json');
    process.exit(1);
  }

  try {
    config = JSON.parse(readFileSync(CONFIG_PATH, 'utf-8'));
  } catch (e) {
    console.error(`Error: Failed to parse config file at ${CONFIG_PATH}`);
    console.error(e.message);
    process.exit(1);
  }
}

// Validate config structure
if (!config.ai_tools || Object.keys(config.ai_tools).length === 0) {
  console.error('Error: No AI tools defined in config');
  process.exit(1);
}

// Select AI tool
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

// Get result suffix (tool-specific or global)
const RESULT_SUFFIX = aiConfig.result_prompt_suffix || config.result_prompt_suffix || '';

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
const AI_CMD = aiConfig.command.replace('{prompt}', ESCAPED_PROMPT);
execSync(`tmux send-keys -t "${SESSION_NAME}:${WINDOW_NAME}" "${AI_CMD}" C-m`, { stdio: 'pipe' });

console.log(`SESSION=${SESSION_NAME}`);
console.log(`WINDOW=${WINDOW_NAME}`);
console.log(`AI_TOOL=${AI_TOOL}`);
