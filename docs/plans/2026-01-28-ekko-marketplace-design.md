# Ekko Marketplace Design

## Overview

Design for the `ekko.bao/ekko-marketplace` repository - a Claude Code plugin marketplace that distributes plugins maintained by ekko.bao.

## Reference

Based on the superpowers marketplace pattern:
- https://github.com/obra/superpowers-marketplace
- https://raw.githubusercontent.com/obra/superpowers-marketplace/main/.claude-plugin/marketplace.json

## Repository Structure

```
ekko-marketplace/                       # Marketplace repository root
├── .claude-plugin/
│   └── marketplace.json                # Marketplace catalog
├── README.md                           # Marketplace documentation
└── LICENSE
```

## marketplace.json Schema

```json
{
  "name": "ekko-marketplace",
  "owner": {
    "name": "ekko.bao",
    "email": "your-email@example.com"
  },
  "metadata": {
    "description": "Claude Code plugins by ekko.bao for workflow automation and development tools",
    "version": "1.0.0"
  },
  "plugins": [
    {
      "name": "tmux-worktree",
      "source": {
        "source": "github",
        "repo": "ekko.bao/tmux-worktree"
      },
      "description": "Creates isolated git worktree development environments with tmux sessions",
      "version": "1.0.0",
      "category": "development",
      "tags": ["git", "workflow", "isolation", "tmux"],
      "strict": true
    }
  ]
}
```

## Installation Flow

```bash
# Users add the marketplace
/plugin marketplace add ekko.bao/ekko-marketplace

# Install plugins from the marketplace
/plugin install tmux-worktree@ekko-marketplace
```

## Source Types

The `source` field supports:
- `github` - Repository from GitHub (use `repo` field)
- `url` - Direct Git URL (use `url` field)

Example:
```json
"source": {
  "source": "github",
  "repo": "ekko.bao/tmux-worktree"
}

// or

"source": {
  "source": "url",
  "url": "https://github.com/ekko.bao/tmux-worktree.git"
}
```

## Adding New Plugins

To add a new plugin to the marketplace:

1. Create the plugin repository following the plugin structure
2. Add entry to `plugins` array in `marketplace.json`
3. Update marketplace version
4. Commit and push changes

## README.md Template

```markdown
# Ekko Marketplace

Claude Code plugins curated by ekko.bao for workflow automation and development tools.

## Installation

Add this marketplace to Claude Code:

```bash
/plugin marketplace add ekko.bao/ekko-marketplace
```

## Available Plugins

### tmux-worktree

**Description:** Creates isolated git worktree development environments with tmux sessions

**Categories:** Git, Workflow, Development

**Install:**
```bash
/plugin install tmux-worktree@ekko-marketplace
```

**Repository:** https://github.com/ekko.bao/tmux-worktree

---

## License

Marketplace metadata: MIT License

Individual plugins: See respective plugin licenses
```

## Files to Create

### 1. `.claude-plugin/marketplace.json`

The core marketplace configuration file.

### 2. `README.md`

Documentation for the marketplace.

### 3. `LICENSE`

MIT License for marketplace metadata.

## Next Steps

1. Create the `ekko-marketplace` repository
2. Add `.claude-plugin/marketplace.json`
3. Add `README.md`
4. Add `LICENSE`
5. Push to GitHub
6. Test installation with `/plugin marketplace add ekko.bao/ekko-marketplace`
