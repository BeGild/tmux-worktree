#!/usr/bin/env python3
"""
Stop hook for tmux-worktree plugin
每次 stop 时返回完整的 progress.md 模板，确保 AI 按正确格式更新

Best practices from:
https://gist.github.com/alexfazio/653c5164d726987569ee8229a19f451f
"""

import os
import subprocess
import sys
import json
import re
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
    """从 progress.md 中提取 Status 字段"""
    if "## Status" not in content:
        return None

    status_section = content.split("## Status")[1].split("##")[0]

    # 移除 HTML 注释，避免匹配到注释中的状态说明
    status_section = re.sub(r'<!--.*?-->', '', status_section, flags=re.DOTALL)

    # 优先查找加粗的状态 **Status**
    for status in ["In Progress", "Completed", "Blocked", "Abandoned", "Waiting for User"]:
        if f"**{status}**" in status_section:
            return status

    # 如果没有找到加粗状态，返回第一个匹配的状态（向后兼容）
    for status in ["In Progress", "Completed", "Blocked", "Abandoned", "Waiting for User"]:
        if status in status_section:
            return status

    return None

def extract_objective(content):
    """从 prompt.md 中提取任务目标（用于上下文提示）"""
    if "## Objective" not in content:
        return ""

    obj_section = content.split("## Objective")[1].split("##")[0]
    return obj_section.strip()[:200]  # 取前200字符

def has_uncommitted_changes():
    """检查是否有未提交的更改"""
    untracked = run_git(["git", "ls-files", "--others", "--exclude-standard"])
    modified = run_git(["git", "diff", "--name-only"])
    staged = run_git(["git", "diff", "--cached", "--name-only"])

    return bool(untracked or modified or staged)

def generate_progress_template(git_info):
    """生成 progress.md 模板（每次 stop 都返回）"""
    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')

    return f"""# Task Progress

## Status
**In Progress** | Waiting for User | Completed | Blocked | Abandoned

<!--
状态说明（选择加粗一个）:
- **In Progress**: 正在工作，需要继续执行任务（不能停止）
- **Waiting for User**: 需要用户决策、确认或输入才能继续（允许停止等待用户）
- **Completed**: 任务已完成（无未提交更改时允许停止）
- **Blocked**: 被外部因素阻塞，如依赖未就绪、API 问题等（允许停止）
- **Abandoned**: 任务已放弃（允许停止）
-->

## Progress Log

### [添加已有的 Progress Log...]

---

## Final Summary

### Overview
{{描述你做了什么}}

### Changes Made
{{总结实现的更改}}

### Files Modified
{git_info}

### Testing
{{描述测试过程和结果}}

### Blockers / Issues
{{如果状态是 Blocked，描述问题。否则写 None}}

### Next Steps
{{描述接下来需要做什么}}

### Cleanup Recommendation
选择一个并说明:
- **Ready to merge** → 可以合并到主分支
- **Continue working** → 保留 worktree 继续工作
- **Cleanup recommended** → 可以安全删除 worktree
- **Needs review** → 清理前需要人工审查

---
_Updated: {timestamp}_
"""

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

        # ========== New file paths ==========
        tmux_dir = os.path.join(current_dir, ".tmux-worktree")
        progress_file = os.path.join(tmux_dir, "progress.md")
        prompt_file = os.path.join(tmux_dir, "prompt.md")
        # ========== End of file paths ==========

        # Check progress.md
        if os.path.exists(progress_file):
            with open(progress_file, 'r', encoding='utf-8') as f:
                content = f.read()
                status = extract_status(content)

                # 方案B: 停止条件
                if status == "Completed":
                    if not has_uncommitted_changes():
                        sys.exit(0)  # 允许停止
                    else:
                        # 读取 prompt.md 获取上下文
                        objective = ""
                        if os.path.exists(prompt_file):
                            with open(prompt_file, 'r', encoding='utf-8') as pf:
                                objective = extract_objective(pf.read())

                        output = {
                            "decision": "block",
                            "reason": f"## 任务已完成但有未提交的文件\n\n**任务目标**: {objective}\n\n请先提交你的工作成果，然后再停止。"
                        }
                        print(json.dumps(output, ensure_ascii=False, indent=2))
                        sys.exit(0)

                elif status == "Blocked":
                    sys.exit(0)

                elif status == "Abandoned":
                    sys.exit(0)

                elif status == "Waiting for User":
                    # AI 正在等待用户决策，允许停止
                    sys.exit(0)

                elif status == "In Progress":
                    # 读取 prompt.md 获取上下文
                    objective = ""
                    if os.path.exists(prompt_file):
                        with open(prompt_file, 'r', encoding='utf-8') as pf:
                            objective = extract_objective(pf.read())

                    # 获取 git 信息
                    untracked = run_git(["git", "ls-files", "--others", "--exclude-standard"])
                    modified = run_git(["git", "diff", "--name-only"])
                    staged = run_git(["git", "diff", "--cached", "--name-only"])
                    current_branch = run_git(["git", "rev-parse", "--abbrev-ref", "HEAD"])

                    files = []
                    if untracked:
                        files.extend([f"  - [未跟踪] {f}" for f in untracked.split('\n') if f])
                    if modified:
                        files.extend([f"  - [已修改] {f}" for f in modified.split('\n') if f])
                    if staged:
                        files.extend([f"  - [已暂存] {f}" for f in staged.split('\n') if f])
                    git_info = "\n".join(files) if files else "  (无)"

                    # 每次都返回完整模板
                    template = generate_progress_template(git_info)
                    output = {
                        "decision": "block",
                        "reason": f"""## 任务还在进行中

**当前分支**: `{current_branch}`
**任务目标**: {objective}

**当前 Status 是 In Progress**，请选择合适的操作：

1. **继续工作** - 保持 `**In Progress**` 状态，继续完成任务
2. **等待用户决策** - 改为 `**Waiting for User**` 状态，允许停止等待用户
3. **任务完成** - 改为 `**Completed**` 状态（需确保无未提交更改）

如果需要更新状态，请编辑 progress.md：

```markdown
{template}
```"""
                    }
                    print(json.dumps(output, ensure_ascii=False, indent=2))
                    sys.exit(0)

        # progress.md 不存在的情况，获取 git 信息并生成初始模板
        untracked_files = run_git(["git", "ls-files", "--others", "--exclude-standard"])
        modified_files = run_git(["git", "diff", "--name-only"])
        staged_files = run_git(["git", "diff", "--cached", "--name-only"])
        current_branch = run_git(["git", "rev-parse", "--abbrevref", "HEAD"])

        files = []
        if untracked_files:
            files.extend([f"  - [未跟踪] {f}" for f in untracked_files.split('\n') if f])
        if modified_files:
            files.extend([f"  - [已修改] {f}" for f in modified_files.split('\n') if f])
        if staged_files:
            files.extend([f"  - [已暂存] {f}" for f in staged_files.split('\n') if f])
        git_info = "\n".join(files) if files else "  (无)"

        template = generate_progress_template(git_info)

        output = {
            "decision": "block",
            "reason": f"## 请创建并填写 progress.md\n\n请创建 `.tmux-worktree/progress.md` 并填写以下模板：\n\n```markdown\n{template}\n```"
        }

        print(json.dumps(output, ensure_ascii=False, indent=2))
        sys.exit(0)

    except Exception as e:
        print(f"[ERROR] Hook failed: {type(e).__name__}: {e}", file=sys.stderr)
        sys.exit(0)

if __name__ == "__main__":
    main()
