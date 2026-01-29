# Prompt & Progress Refactor Design

**Date:** 2026-01-29
**Status:** Design
**Author:** Claude

## Overview

将当前单一的 `RESULT.md` 重构为两个职责明确的文件：
- **`.tmux-worktree/prompt.md`** - 任务启动时保存的原始提示词
- **`.tmux-worktree/progress.md`** - 任务进度跟踪和结果总结

### Motivation

**问题：** 当前直接将 prompt 传给 AI 工具，无法追溯初始任务意图

**解决：**
1. 持久化 prompt 到文件，确保任务意图可追溯
2. 每次 stop 时提供标准模板确保正确更新
3. AI 可在工作中持续更新进度

### Key Changes

- Main Agent 按 SKILL.md 模板生成结构化 prompt
- setup 脚本自动保存 prompt 到 `prompt.md`
- setup 脚本通过 `cat prompt.md | ai-tool` 驱动 AI
- stop hook 每次返回完整模板确保格式正确

## File Structure

```
.worktrees/
└── add-oauth2-login/
    ├── .git/                          # git worktree metadata
    ├── .tmux-worktree/                # 任务管理目录
    │   ├── prompt.md                  # 任务提示词（setup时保存）
    │   └── progress.md                # 进度跟踪（setup生成模板，AI持续更新）
    ├── [项目代码...]
    └── [其他文件...]
```

## File Templates

### prompt.md 模板（在 SKILL.md 中定义）

```markdown
# Task: {任务名称}

## Context
- **Branch**: {分支名}
- **Worktree**: {worktree相对路径}

## Objective
{清晰描述任务目标，1-2句话}

## Original Request
{用户的原始请求内容}

## Constraints
- 工作目录限制在当前 worktree 内
- 完成后更新 .tmux-worktree/progress.md 记录结果
- 遵循项目的代码规范

## Success Criteria
{明确任务完成的验收标准}
```

### progress.md 模板

```markdown
# Task Progress

## Status
**In Progress** | Completed | Blocked | Abandoned

## Progress Log

### [{时间戳}] 任务启动
- 阅读 .tmux-worktree/prompt.md 了解任务目标
- 开始工作...

### [添加更多里程碑...]
---

## Final Summary

### Overview
{描述你做了什么}

### Changes Made
{总结实现的更改}

### Files Modified
{git 状态将自动填充到这里}

### Testing
{描述测试过程和结果}

### Blockers / Issues
{如果状态是 Blocked，描述问题。否则写 None}

### Next Steps
{描述接下来需要做什么}

### Cleanup Recommendation
选择一个并说明:
- **Ready to merge** → 可以合并到主分支
- **Continue working** → 保留 worktree 继续工作
- **Cleanup recommended** → 可以安全删除 worktree
- **Needs review** → 清理前需要人工审查

---
_Updated: {最后更新时间}_
```

## Architecture Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          CREATE Phase (Main Agent)                          │
├─────────────────────────────────────────────────────────────────────────────┤
│  1. Main Agent 按 SKILL.md 模板生成结构化 prompt                             │
│  2. tmux-worktree create "task-name"                                        │
│  3. tmux-worktree setup "worktree-path" "task-name" "ai-tool" "<prompt>"    │
│     → 脚本自动保存 prompt 到 .tmux-worktree/prompt.md                       │
│     → 脚本生成空 progress.md 模板                                            │
│     → 脚本执行: cat .tmux-worktree/prompt.md | ai-tool                      │
└─────────────────────────────────────────────────────────────────────────────┘
                                       │
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                            WORK Phase (Worktree AI)                         │
├─────────────────────────────────────────────────────────────────────────────┤
│  1. 接收 prompt.md 内容开始任务                                              │
│  2. 开发工作中...                                                            │
│  3. stop 触发时更新 progress.md                                              │
└─────────────────────────────────────────────────────────────────────────────┘
                                       │
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         STOP Phase (Hook)                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│  1. 读取 progress.md 检查 Status                                             │
│  2. 如果需要 block，返回：                                                   │
│     - 标准的 progress.md 模板（每次都返回，确保格式正确）                     │
│     - 当前 git 状态信息                                                     │
│     - 结合 prompt.md 的任务上下文提示                                        │
│  3. AI 按照模板更新 progress.md                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Implementation Changes

### 1. setup.js 修改

**关键变更：**
- 创建 `.tmux-worktree` 目录
- 写入 `prompt.md`（从接收的 PROMPT 参数）
- 生成空的 `progress.md` 模板
- 修改 AI 调用方式：`cat .tmux-worktree/prompt.md | ai-tool`

**代码片段：**
```javascript
// 创建 .tmux-worktree 目录
const TMUX_DIR = `${WORKTREE_PATH}/.tmux-worktree`;
if (!existsSync(TMUX_DIR)) {
  mkdirSync(TMUX_DIR, { recursive: true });
}

// 写入 prompt.md
const PROMPT_FILE = `${TMUX_DIR}/prompt.md`;
writeFileSync(PROMPT_FILE, PROMPT, 'utf-8');

// 生成 progress.md 空模板
const PROGRESS_FILE = `${TMUX_DIR}/progress.md`;
const progressTemplate = generateProgressTemplate();
writeFileSync(PROGRESS_FILE, progressTemplate, 'utf-8');

// 通过 cat 驱动 AI
const AI_CMD = `cat ${PROMPT_FILE} | ${aiConfig.command}`;
execSync(`tmux send-keys -t "${SESSION_NAME}:${WINDOW_NAME}" "${AI_CMD}" C-m`);
```

### 2. session-stop.py 修改

**关键变更：**
- 文件路径：`RESULT.md` → `.tmux-worktree/progress.md`
- 新增读取 `prompt.md` 获取任务上下文
- 每次都返回完整 progress.md 模板
- 保持原方案 B 停止条件

**代码片段：**
```python
tmux_dir = os.path.join(current_dir, ".tmux-worktree")
progress_file = os.path.join(tmux_dir, "progress.md")
prompt_file = os.path.join(tmux_dir, "prompt.md")

# 读取 prompt.md 获取任务目标
objective = ""
if os.path.exists(prompt_file):
    with open(prompt_file, 'r') as f:
        objective = extract_objective(f.read())

# 每次都返回完整模板
template = generate_progress_template(git_info)
output = {
    "decision": "block",
    "reason": f"**任务目标**: {objective}\n\n请更新 progress.md:\n\n```markdown\n{template}\n```"
}
```

### 3. list.js 修改

**关键变更：**
- 路径：`RESULT.md` → `.tmux-worktree/progress.md`
- 提取 Status 字段显示

**代码片段：**
```javascript
const progressPath = `${path}/.tmux-worktree/progress.md`;
const content = readFileSync(progressPath, 'utf-8');

// 提取 Status 字段
const statusMatch = content.match(/## Status\s+\*\*(In Progress|Completed|Blocked|Abandoned)\*\*/);
progressStatus = statusMatch ? statusMatch[1] : '-';
```

### 4. .gitignore 更新

```gitignore
# Worktrees
.worktrees/

# Tmux-worktree task management
.tmux-worktree/
```

### 5. CONFIG.md 更新

**关键变更：**
- 移除 `{prompt}` 占位符说明
- 更新为：command 通过 stdin 接收输入

**旧版：**
```json
{
  "command": "claude '{prompt}'"
}
```

**新版：**
```json
{
  "command": "claude"
}
```

### 6. SKILL.md 更新

**新增内容：**
- Prompt Template 章节（规范 Main Agent 如何生成 prompt）
- 更新 Project Setup（.gitignore 条目）
- 更新 Phase 1 CREATE（添加生成结构化 prompt 的步骤）
- 更新 Phase 2 WORK（说明 prompt.md 和 progress.md 的作用）
- 更新 Phase 3 CLEANUP（说明读取 progress.md）
- 更新 Quick Reference（命令说明）

## Data Flow Summary

```
Main Agent 生成结构化 prompt（按 SKILL.md 模板）
    │
    ▼
tmux-worktree setup "<worktree>" "<task>" "<tool>" "<prompt>"
    │
    ├─► 创建 .tmux-worktree/ 目录
    ├─► 保存 prompt → prompt.md
    ├─► 生成空模板 → progress.md
    └─► 执行: cat prompt.md | ai-tool
            │
            ▼
        Worktree AI 开始工作
            │
            ▼
        stop hook 触发
            │
            ├─► 读取 progress.md 检查 Status
            ├─► 读取 prompt.md 获取任务上下文
            └─► 返回完整模板 + git 状态
            │
            ▼
        AI 按模板更新 progress.md
```

## Stop Conditions (保持方案 B)

| Status | Git 状态 | 行为 |
|--------|----------|------|
| Completed | 干净 | 允许停止 |
| Completed | 有未提交 | 阻止，要求提交 |
| In Progress | 任意 | 阻止，要求继续或更新状态 |
| Blocked | 任意 | 允许停止 |
| Abandoned | 任意 | 允许停止 |
| 未设置 | 任意 | 阻止，要求选择状态 |

## Migration Notes

- 不需要兼容旧 RESULT.md，直接替换
- 旧 worktree 如果有 RESULT.md，cleanup 时按旧逻辑处理
- 新 worktree 全部使用新结构

## Testing Checklist

- [ ] setup 创建 .tmux-worktree/ 目录
- [ ] setup 保存 prompt.md
- [ ] setup 生成 progress.md 模板
- [ ] AI 通过 cat 接收 prompt
- [ ] stop hook 正确读取 progress.md
- [ ] stop hook 正确读取 prompt.md 上下文
- [ ] stop hook 每次返回完整模板
- [ ] list 显示 progress.md 的 Status
- [ ] .gitignore 包含 .tmux-worktree/
- [ ] 配置文件不需要 {prompt} 占位符
