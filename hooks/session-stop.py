#!/usr/bin/env python3
"""
Stop hook for tmux-worktree plugin
Blocks stop to ensure AI generates RESULT.md before ending session

Best practices from:
https://gist.github.com/alexfazio/653c5164d726987569ee8229a19f451f
"""

import os
import subprocess
import sys
import json
import time

def run_git(cmd):
    """Run git command and return output"""
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            cwd=os.getcwd(),
            timeout=5
        )
        return result.stdout.strip()
    except:
        return ""

def main():
    try:
        # 读取 hook 输入
        try:
            input_data = json.loads(sys.stdin.read())
        except:
            input_data = {}

        stop_hook_active = input_data.get("stop_hook_active", False)

        # Get current working directory
        current_dir = os.getcwd()

        # Check if we're in a git repository
        git_dir = os.path.join(current_dir, ".git")
        if not os.path.exists(git_dir):
            sys.exit(0)

        # Check if this is a worktree (not the main repo)
        if os.path.isdir(git_dir):
            # .git is a directory → main repo, not a worktree
            sys.exit(0)
        elif not os.path.isfile(git_dir):
            sys.exit(0)

        # 检查 RESULT.md 是否存在且已更新
        result_file = os.path.join(current_dir, "RESULT.md")
        if os.path.exists(result_file):
            # 检查文件是否有 Status 字段（说明AI已经按格式更新过）
            with open(result_file, 'r', encoding='utf-8') as f:
                content = f.read()
                if "## Status" in content:
                    # AI已更新过RESULT.md，允许停止
                    sys.exit(0)

        # 自动检测 git 状态
        untracked_files = run_git(["git", "ls-files", "--others", "--exclude-standard"])
        modified_files = run_git(["git", "diff", "--name-only"])
        staged_files = run_git(["git", "diff", "--cached", "--name-only"])
        current_branch = run_git(["git", "rev-parse", "--abbrev-ref", "HEAD"])
        recent_commits = run_git(["git", "log", "--oneline", "-5"])

        # 构建未提交文件列表
        uncommitted_files = []
        if untracked_files:
            uncommitted_files.extend([f"  - [未跟踪] {f}" for f in untracked_files.split('\n') if f])
        if modified_files:
            uncommitted_files.extend([f"  - [已修改] {f}" for f in modified_files.split('\n') if f])
        if staged_files:
            uncommitted_files.extend([f"  - [已暂存] {f}" for f in staged_files.split('\n') if f])

        # ===========================================================================
        # Prompt for AI - Generate RESULT.md
        # ===========================================================================

        if uncommitted_files:
            files_section = f"""## 当前工作区状态

你有以下未提交的文件：
{chr(10).join(uncommitted_files)}

请检查这些文件：
- 如果是本次任务的成果，请提交它们
- 如果是临时文件或无关修改，请在 RESULT.md 的 "Files Modified" 部分标记为 "无需提交"
"""
        else:
            files_section = """## 当前工作区状态

工作区干净，没有未提交的文件。
"""

        INSTRUCTION = f"""你正在一个 git worktree 环境中工作。在停止之前，你**必须创建 RESULT.md** 来记录你的工作进展。

{files_section}## 检查清单

创建 RESULT.md 之前，我已经自动为你收集了以下信息：

- **当前分支**: `{current_branch or 'unknown'}`
- **最近提交**:
```
{recent_commits or '无'}
```

## 重要提示

- 如果有未提交的成果文件，请先提交
- 临时文件或测试文件请在 RESULT.md 中标记为"无需提交"
- 创建完 RESULT.md 后，你可以停止

## RESULT.md 模板

请按以下格式创建 RESULT.md：

```markdown
# Task Summary

## Status
[选择一个: In Progress / Completed / Blocked / Abandoned]

## Overview
[简要描述你做了什么]

## Changes Made
[总结实现的更改]

## Files Modified
[列出修改的文件 - 临时文件标注为"无需提交"]

## Commits
[列出本次任务的 commits - 使用上面"最近提交"中的相关提交]

## Testing
[描述测试过程和结果]

## Blockers / Issues
[如果状态是 Blocked，描述问题。否则写 `None`]

## Next Steps
[接下来需要做什么？]

## Cleanup Recommendation
[选择一个并说明:
- Ready to merge → 可以合并到主分支
- Continue working → 保留 worktree 继续工作
- Cleanup recommended → 可以安全删除 worktree
- Needs review → 清理前需要人工审查]
```
"""

        # ===========================================================================
        # Block stop and show prompt
        # ===========================================================================

        output = {
            "decision": "block",
            "reason": INSTRUCTION
        }

        print(json.dumps(output, ensure_ascii=False, indent=2))
        sys.exit(0)

    except Exception as e:
        # Log error to stderr and exit gracefully
        print(f"[ERROR] Hook failed: {type(e).__name__}: {e}", file=sys.stderr)
        sys.exit(0)

if __name__ == "__main__":
    main()
