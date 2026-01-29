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
from datetime import datetime

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

def extract_status(content):
    """从 RESULT.md 中提取 Status 字段"""
    if "## Status" not in content:
        return None

    # 找到 Status 部分
    status_section = content.split("## Status")[1].split("##")[0]

    # 检查是否包含有效状态
    for status in ["Completed", "Blocked", "Abandoned", "In Progress"]:
        if status in status_section:
            return status

    return None

def has_uncommitted_changes():
    """检查是否有未提交的更改"""
    untracked = run_git(["git", "ls-files", "--others", "--exclude-standard"])
    modified = run_git(["git", "diff", "--name-only"])
    staged = run_git(["git", "diff", "--cached", "--name-only"])

    return bool(untracked or modified or staged)

def main():
    try:
        # 读取 hook 输入
        try:
            input_data = json.loads(sys.stdin.read())
        except:
            input_data = {}

        # 检查 CLAUDE_PROJECT_DIR 是否在 .worktrees 目录下
        project_dir = os.environ.get("CLAUDE_PROJECT_DIR")
        if not project_dir or "/.worktrees/" not in project_dir:
            sys.exit(0)

        # Get current working directory
        current_dir = os.getcwd()

        # Check if we're in a git repository
        git_dir = os.path.join(current_dir, ".git")
        if not os.path.exists(git_dir):
            sys.exit(0)

        # Check if this is a worktree (not the main repo)
        if os.path.isdir(git_dir):
            sys.exit(0)
        elif not os.path.isfile(git_dir):
            sys.exit(0)

        result_file = os.path.join(current_dir, "RESULT.md")

        # 检查 RESULT.md 是否已存在
        if os.path.exists(result_file):
            with open(result_file, 'r', encoding='utf-8') as f:
                content = f.read()
                status = extract_status(content)

                # 方案B: 停止条件
                if status == "Completed":
                    # Completed 状态：需要工作区干净才能停止
                    if not has_uncommitted_changes():
                        sys.exit(0)  # 允许停止
                    else:
                        # 有未提交文件，要求先提交
                        output = {
                            "decision": "block",
                            "reason": "## 任务已完成但有未提交的文件\n\n请先提交你的工作成果，然后再停止。"
                        }
                        print(json.dumps(output, ensure_ascii=False, indent=2))
                        sys.exit(0)

                elif status == "Blocked":
                    # Blocked 状态：允许停止（需要人工介入）
                    sys.exit(0)

                elif status == "Abandoned":
                    # Abandoned 状态：允许停止
                    sys.exit(0)

                elif status == "In Progress":
                    # In Progress 状态：要求继续工作
                    output = {
                        "decision": "block",
                        "reason": "## 任务还在进行中\n\n当前 Status 是 **In Progress**，请继续完成任务。\n\n如果任务确实已完成，请将 Status 改为 **Completed**。"
                    }
                    print(json.dumps(output, ensure_ascii=False, indent=2))
                    sys.exit(0)

        # 自动检测 git 状态
        untracked_files = run_git(["git", "ls-files", "--others", "--exclude-standard"])
        modified_files = run_git(["git", "diff", "--name-only"])
        staged_files = run_git(["git", "diff", "--cached", "--name-only"])
        current_branch = run_git(["git", "rev-parse", "--abbrev-ref", "HEAD"])
        recent_commits = run_git(["git", "log", "--oneline", "-10"])

        # 构建文件列表
        uncommitted_files = []
        if untracked_files:
            uncommitted_files.extend([f"  - [未跟踪] {f}" for f in untracked_files.split('\n') if f])
        if modified_files:
            uncommitted_files.extend([f"  - [已修改] {f}" for f in modified_files.split('\n') if f])
        if staged_files:
            uncommitted_files.extend([f"  - [已暂存] {f}" for f in staged_files.split('\n') if f])

        files_list = "\n".join(uncommitted_files) if uncommitted_files else "  (无)"

        # 生成 RESULT.md 内容
        result_content = f"""# Task Summary

## Status
请选择一个: In Progress / Completed / Blocked / Abandoned

## Overview
请描述你做了什么

## Changes Made
请总结实现的更改

## Files Modified
{files_list}

注：如果是成果文件请先提交，如果是临时文件在此说明

## Commits
当前分支: `{current_branch or 'unknown'}`

最近提交:
```
{recent_commits or '无'}
```

## Testing
请描述测试过程和结果

## Blockers / Issues
如果状态是 Blocked，描述问题。否则写 `None`

## Next Steps
请描述接下来需要做什么

## Cleanup Recommendation
请选择一个并说明:
- Ready to merge → 可以合并到主分支
- Continue working → 保留 worktree 继续工作
- Cleanup recommended → 可以安全删除 worktree
- Needs review → 清理前需要人工审查

---
_生成时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}_
"""

        # 写入 RESULT.md
        with open(result_file, 'w', encoding='utf-8') as f:
            f.write(result_content)

        # 提示 AI 填写内容
        INSTRUCTION = """已为你生成 **RESULT.md** 模板，git信息已自动填入。

## 你需要做的

请编辑 RESULT.md，首先选择正确的 **Status**：

1. **In Progress** → 任务进行中，填写后系统会要求你继续工作
2. **Completed** → 任务已完成，**必须先提交所有成果文件**，然后才能停止
3. **Blocked** → 遇到阻塞无法继续，可以立即停止（等待人工介入）
4. **Abandoned** → 任务中止，可以立即停止

然后填写其他字段：
- Overview, Changes Made, Testing, Blockers, Next Steps, Cleanup Recommendation

## 注意

- **Completed 状态必须工作区干净（无未提交文件）才能停止**
- Blocked/Abandoned 状态可以随时停止"""

        output = {
            "decision": "block",
            "reason": INSTRUCTION
        }

        print(json.dumps(output, ensure_ascii=False, indent=2))
        sys.exit(0)

    except Exception as e:
        print(f"[ERROR] Hook failed: {type(e).__name__}: {e}", file=sys.stderr)
        sys.exit(0)

if __name__ == "__main__":
    main()
