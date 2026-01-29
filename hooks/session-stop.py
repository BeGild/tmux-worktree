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

def main():
    try:
        # 读取 hook 输入
        try:
            input_data = json.loads(sys.stdin.read())
        except:
            input_data = {}

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

        # 检查 RESULT.md 是否已存在且有 Status 字段
        if os.path.exists(result_file):
            with open(result_file, 'r', encoding='utf-8') as f:
                content = f.read()
                if "## Status" in content:
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
<!-- 请选择一个: In Progress / Completed / Blocked / Abandoned -->

## Overview
<!-- 请描述你做了什么 -->

## Changes Made
<!-- 请总结实现的更改 -->

## Files Modified
<!-- AUTO-GENERATED: 请勿修改以下内容 -->
{files_list}
<!-- END AUTO-GENERATED -->
<!-- 注：如果是成果文件请先提交，如果是临时文件在此说明 -->

## Commits
<!-- AUTO-GENERATED: 请勿修改以下内容 -->
当前分支: `{current_branch or 'unknown'}`

最近提交:
```
{recent_commits or '无'}
```
<!-- END AUTO-GENERATED -->

## Testing
<!-- 请描述测试过程和结果 -->

## Blockers / Issues
<!-- 如果状态是 Blocked，描述问题。否则写 `None` -->

## Next Steps
<!-- 请描述接下来需要做什么 -->

## Cleanup Recommendation
<!-- 请选择一个并说明:
- Ready to merge → 可以合并到主分支
- Continue working → 保留 worktree 继续工作
- Cleanup recommended → 可以安全删除 worktree
- Needs review → 清理前需要人工审查 -->

---
_生成时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}_
"""

        # 写入 RESULT.md
        with open(result_file, 'w', encoding='utf-8') as f:
            f.write(result_content)

        # 提示 AI 填写内容
        INSTRUCTION = """已为你生成 **RESULT.md** 模板，git信息已自动填入。

## 你需要做的

请编辑 RESULT.md，填写以下字段：

1. **Status**: 选择任务状态 (In Progress/Completed/Blocked/Abandoned)
2. **Overview**: 简要描述你做了什么
3. **Changes Made**: 总结实现的更改
4. **Testing**: 描述测试过程和结果
5. **Blockers / Issues**: 如有阻塞问题请描述
6. **Next Steps**: 接下来需要做什么
7. **Cleanup Recommendation**: 选择清理建议

## 注意

- `<!-- AUTO-GENERATED -->` 标记的内容为自动生成，请勿修改
- 未提交的成果文件请先提交
- 临时文件在 "Files Modified" 部分标注为"无需提交"

填写完成后即可停止。"""

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
