#!/bin/bash
set -e

echo "=== tmux-worktree Workflow Test ==="
echo ""

# Create temp repo
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"
git init
git config user.name "Test User"
git config user.email "test@example.com"
echo "# Test" > README.md
git add README.md
git commit -m "Initial commit"

echo "Test repo created: $TEMP_DIR"
echo ""

# Test 1: Create worktree
echo "Test 1: Create worktree"
bash ../tmux-worktree/scripts/create-worktree.sh "test feature"
echo "✓ Worktree created"
echo ""

# Test 2: List worktrees
echo "Test 2: List worktrees"
bash ../tmux-worktree/scripts/list-worktrees.sh
echo "✓ List works"
echo ""

# Cleanup
cd -
rm -rf "$TEMP_DIR"

echo "=== All tests passed ==="
