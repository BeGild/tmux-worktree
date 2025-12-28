#!/bin/bash
# skills.sh - AI Skills generation

# Get skills directory for AI tool
skills_get_dir() {
    local ai_tool="$1"
    local scope="$2"  # 'user' or 'project'
    local base_path=""

    case "$scope" in
        user)
            base_path="$HOME"
            ;;
        project)
            base_path="${3:-.}"  # default to current directory
            ;;
    esac

    case "$ai_tool" in
        claude)
            echo "${base_path}/.claude/skills"
            ;;
        codex)
            echo "${base_path}/.codex/skills"
            ;;
        *)
            echo "${base_path}/.${ai_tool}/skills"
            ;;
    esac
}

# Get context file name for AI tool
skills_get_context_file() {
    local ai_tool="$1"

    case "$ai_tool" in
        codex)
            echo "AGENTS.md"
            ;;
        *)
            echo "AGENTS.md"  # Uppercase the tool name
            ;;
    esac
}

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

skills_generate_task_skill() {
    local branch_name="$1"
    local task_description="$2"
    local worktree_path="$3"
    local original_branch="$4"
    local original_path="$5"

    cat <<EOF
---
name: task-context
description: Context for tm-task: ${task_description}
---

# Task Context

## Task
${task_description}

## Branch
- Current: \`${branch_name}\`
- Base: \`${original_branch}\`
- Original: \`${original_path}\`

## Worktree
\`${worktree_path}\`

## Project Structure
\`\`\`
$(skills_generate_structure "$worktree_path")
\`\`\`

## Workflow
1. Review task description
2. Explore codebase
3. Implement changes
4. Test
5. Commit and push (create PR manually)
EOF
}

skills_inject() {
    local worktree_path="$1"
    local branch_name="$2"
    local task_description="$3"
    local original_path="${4:-$(pwd)}"
    local ai_tool="${5:-claude}"  # AI tool to use

    if [[ "${SKILL_ENABLED:-true}" != "true" ]]; then
        return 0
    fi

    # Get AI tool-specific skills directory
    local worktree_skills_dir
    worktree_skills_dir=$(skills_get_dir "$ai_tool" project "$worktree_path")

    # Create task-context skill
    mkdir -p "${worktree_skills_dir}/task-context"

    local original_branch
    original_branch=$(git_worktree_get_current_branch)

    skills_generate_task_skill \
        "$branch_name" "$task_description" "$worktree_path" \
        "$original_branch" "$original_path" \
        > "${worktree_skills_dir}/task-context/SKILL.md"

    # Smart copy: Only copy if user-level skill doesn't exist
    local user_skills_dir
    user_skills_dir=$(skills_get_dir "$ai_tool" user)

    local project_skills_dir
    project_skills_dir=$(skills_get_dir "$ai_tool" project "$original_path")

    if [[ ! -d "${user_skills_dir}/tmux-git-worktree" ]] && \
       [[ -d "${project_skills_dir}/tmux-git-worktree" ]]; then
        # User-level skill not found, copy from project
        mkdir -p "$worktree_skills_dir"
        cp -r "${project_skills_dir}/tmux-git-worktree" "${worktree_skills_dir}/"
    fi

    # Create AI tool-specific context file in worktree root
    local context_file
    context_file=$(skills_get_context_file "$ai_tool")

    cat > "${worktree_path}/${context_file}" <<EOF
# Task: ${task_description}

Working in git worktree for this task.
- Branch: \`${branch_name}\`
- Base: \`${original_branch}\`

Use \`task-context\` skill for full details.
EOF
}
