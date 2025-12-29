#!/bin/bash
# skills.sh - AI initial prompt generation

# Generate project structure for context
skills_generate_structure() {
    local worktree_path="$1"
    cd "$worktree_path"

    if command -v tree >/dev/null 2>&1; then
        tree -L 2 -I 'node_modules|.git|dist|build' --dirsfirst
    else
        find . -type f -not -path '*/node_modules/*' -not -path '*/.git/*' \
            -not -path '*/dist/*' -not -path '*/build/*' -maxdepth 2 | head -50
    fi
}

# Generate initial prompt for AI
skills_generate_prompt() {
    local task_description="$1"
    local branch_name="$2"
    local base_branch="$3"
    local worktree_path="$4"
    local original_path="$5"

    cat <<EOF
# Task Environment Setup

You are now in a fresh git worktree for a specific task.

## Task Information
- **Task:** $task_description
- **Branch:** $branch_name (base: $base_branch)
- **Worktree:** $worktree_path
- **Original Path:** $original_path

## What You Should Do

**IMPORTANT:** Before starting work, generate and display a complete initial prompt that includes:

1. **Understanding the Task** - Restate the task in your own words to confirm understanding
2. **Planning** - Outline the approach you will take to complete this task
3. **Implementation Steps** - Break down the work into specific, actionable steps
4. **Testing Strategy** - Describe how you will verify the implementation

Example initial prompt format:
\`\`\`
# Initial Prompt for: <task description>

## My Understanding
[Restate the task to confirm understanding]

## My Approach
[Outline the technical approach]

## Implementation Plan
1. [Step 1]
2. [Step 2]
...

## Testing Strategy
[How to verify the implementation]

---
Ready to proceed. Please confirm or adjust this plan.
\`\`\`

## Project Structure
\`\`\`
$(skills_generate_structure "$worktree_path")
\`\`\`

## Workflow

1. **Generate Initial Prompt** - Create a complete prompt as shown above
2. **Wait for Confirmation** - User will approve or adjust the plan
3. **Execute** - Implement the approved plan
4. **Test** - Verify the implementation
5. **Commit** - Commit changes with descriptive message

## Cleanup

When done, **close the tmux window** (Ctrl+d to exit AI, then the window closes, or use prefix+&).
The worktree will auto-clean if no uncommitted changes.
EOF
}
