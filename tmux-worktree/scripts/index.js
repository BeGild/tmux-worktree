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
