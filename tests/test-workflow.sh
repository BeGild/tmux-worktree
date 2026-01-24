#!/bin/bash
set -e

echo "=== tmux-worktree Workflow Test ==="
echo ""

# Get script directory for absolute path resolution
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CREATE_WORKTREE_SCRIPT="$PROJECT_ROOT/tmux-worktree/scripts/create-worktree.sh"
LIST_WORKTREES_SCRIPT="$PROJECT_ROOT/tmux-worktree/scripts/list-worktrees.sh"

# Verify scripts exist
if [ ! -f "$CREATE_WORKTREE_SCRIPT" ]; then
  echo "Error: create-worktree.sh not found at $CREATE_WORKTREE_SCRIPT" >&2
  exit 1
fi

if [ ! -f "$LIST_WORKTREES_SCRIPT" ]; then
  echo "Error: list-worktrees.sh not found at $LIST_WORKTREES_SCRIPT" >&2
  exit 1
fi

# Save original directory
ORIGINAL_DIR="$(pwd)"

# Create temp repo
TEMP_DIR=$(mktemp -d)
echo "Test repo created: $TEMP_DIR"

# Cleanup trap - ensures temp directory is removed even if tests fail
cleanup() {
  local exit_code=$?
  cd "$ORIGINAL_DIR" 2>/dev/null || true
  if [ -d "$TEMP_DIR" ]; then
    rm -rf "$TEMP_DIR"
  fi
  if [ $exit_code -ne 0 ]; then
    echo "Test failed with exit code $exit_code" >&2
  fi
  exit $exit_code
}
trap cleanup EXIT

cd "$TEMP_DIR"
git init -q
git config user.name "Test User"
git config user.email "test@example.com"
echo "# Test" > README.md
git add README.md
git commit -q -m "Initial commit"

echo ""

# Test 1: Create worktree
echo "Test 1: Create worktree"
OUTPUT=$(bash "$CREATE_WORKTREE_SCRIPT" "test feature" 2>&1)

# Extract worktree path and branch name from output
WORKTREE_PATH=$(echo "$OUTPUT" | grep "^WORKTREE_PATH=" | cut -d'=' -f2)
BRANCH_NAME=$(echo "$OUTPUT" | grep "^BRANCH_NAME=" | cut -d'=' -f2)

# Assertions
if [ -z "$WORKTREE_PATH" ]; then
  echo "✗ Failed: WORKTREE_PATH not found in output" >&2
  echo "Output: $OUTPUT" >&2
  exit 1
fi

if [ -z "$BRANCH_NAME" ]; then
  echo "✗ Failed: BRANCH_NAME not found in output" >&2
  echo "Output: $OUTPUT" >&2
  exit 1
fi

if [ ! -d "$WORKTREE_PATH" ]; then
  echo "✗ Failed: Worktree directory not created at $WORKTREE_PATH" >&2
  exit 1
fi

if ! git worktree list | grep -q "$WORKTREE_PATH"; then
  echo "✗ Failed: Worktree not registered in git worktree list" >&2
  exit 1
fi

if ! git branch | grep -q "$BRANCH_NAME"; then
  echo "✗ Failed: Branch $BRANCH_NAME not created" >&2
  exit 1
fi

echo "✓ Worktree created at $WORKTREE_PATH"
echo "✓ Branch $BRANCH_NAME created"
echo ""

# Test 2: List worktrees
echo "Test 2: List worktrees"
LIST_OUTPUT=$(bash "$LIST_WORKTREES_SCRIPT" 2>&1)

# Assertions
if ! echo "$LIST_OUTPUT" | grep -q "$BRANCH_NAME"; then
  echo "✗ Failed: Branch $BRANCH_NAME not found in list output" >&2
  echo "Output: $LIST_OUTPUT" >&2
  exit 1
fi

if ! echo "$LIST_OUTPUT" | grep -q "test-feature"; then
  echo "✗ Failed: Worktree path 'test-feature' not found in list output" >&2
  echo "Output: $LIST_OUTPUT" >&2
  exit 1
fi

echo "✓ List works - found $BRANCH_NAME"
echo ""

echo "=== All tests passed ==="
