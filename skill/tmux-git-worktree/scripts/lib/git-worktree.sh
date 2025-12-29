#!/bin/bash
# git-worktree.sh - Worktree management

git_worktree_check_repo() {
    git rev-parse --git-dir >/dev/null 2>&1
}

git_worktree_get_project_name() {
    local repo_root
    repo_root=$(git rev-parse --show-toplevel)
    basename "$repo_root"
}

git_worktree_get_base_dir() {
    local worktree_base="${WORKTREE_BASE:-~/.local/tmux-git-worktrees}"
    local project_name
    project_name=$(git_worktree_get_project_name)

    worktree_base="${worktree_base/#\~/$HOME}"

    if [[ "$worktree_base" = /* ]]; then
        echo "${worktree_base}/${project_name}"
    else
        local repo_root
        repo_root=$(git rev-parse --show-toplevel)
        echo "${repo_root}/${worktree_base}/${project_name}"
    fi
}

git_worktree_create() {
    local branch_name="$1"
    local base_dir
    base_dir=$(git_worktree_get_base_dir)

    mkdir -p "$base_dir"
    local worktree_path="${base_dir}/${branch_name}"

    if [[ -d "$worktree_path" ]]; then
        echo "Worktree exists: $worktree_path" >&2
        return 1
    fi

    git worktree add -b "$branch_name" "$worktree_path" >/dev/null

    # Add .gitignore for tm-task temp files
    cat > "${worktree_path}/.gitignore" <<'EOF'
# tm-task temporary files
.tm-task-prompt.tmp
EOF

    echo "$worktree_path"
}

git_worktree_has_changes() {
    local worktree_path="$1"
    # First check if worktree still exists
    [[ ! -d "$worktree_path" ]] && return 1
    # Check for uncommitted changes (excluding untracked files)
    git -C "$worktree_path" diff-index --quiet HEAD -- 2>/dev/null
    return $?
}

git_worktree_delete() {
    local worktree_path="$1"
    local branch_name="$2"
    # Remove the temporary prompt file first
    rm -f "${worktree_path}/.tm-task-prompt.tmp" 2>/dev/null || true
    # Remove the worktree (force to remove untracked files like .gitignore)
    git worktree remove --force "$worktree_path" 2>/dev/null || true
    # Prune to clean up worktree metadata
    git worktree prune 2>/dev/null || true
    # Delete the branch
    git branch -D "$branch_name" 2>/dev/null || true
}

git_worktree_get_current_branch() {
    git branch --show-current
}

git_worktree_get_base_branch() {
    if git show-ref --verify --quiet refs/heads/main; then
        echo "main"
    elif git show-ref --verify --quiet refs/heads/master; then
        echo "master"
    else
        git_worktree_get_current_branch
    fi
}
