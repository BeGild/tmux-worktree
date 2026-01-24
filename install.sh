#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$SCRIPT_DIR/tmux-worktree"

# Check if skill directory exists
if [ ! -d "$SKILL_DIR" ]; then
  echo "Error: tmux-worktree skill directory not found at: $SKILL_DIR" >&2
  exit 1
fi

# Detect skills directory (Claude Code)
SKILLS_DEST="${XDG_CONFIG_HOME:-$HOME/.config}/claude/skills"

if [ ! -d "$SKILLS_DEST" ]; then
  echo "Creating skills directory: $SKILLS_DEST"
  mkdir -p "$SKILLS_DEST"
fi

# Copy skill
echo "Installing skill to: $SKILLS_DEST"
cp -r "$SKILL_DIR" "$SKILLS_DEST/"

# Create config directory and template
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/tmux-worktree"
mkdir -p "$CONFIG_DIR"

if [ ! -f "$CONFIG_DIR/config.yaml" ]; then
  cp "$SKILL_DIR/assets/config-template.yaml" "$CONFIG_DIR/config.yaml"
  echo "Created config: $CONFIG_DIR/config.yaml"
  echo "Please edit this file to configure your AI tool."
else
  echo "Config already exists: $CONFIG_DIR/config.yaml"
fi

echo ""
echo "Installation complete!"
echo "Skill installed at: $SKILLS_DEST/tmux-worktree"
echo "Config location: $CONFIG_DIR/config.yaml"
