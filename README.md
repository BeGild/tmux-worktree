# Tmux Git Worktree - Claude Code Skill

基于 Tmux + Git Worktree 的上下文交换工作流。

## 快速开始

```bash
# 使用 npx 运行安装器（无需预先安装）
npx -y tmux-worktree-install
```

安装器会引导你完成：
1. **选择 AI 工具** - Claude Code 或 Codex
2. **选择安装位置** - Project (`./.claude/skills/`) 或 User (`~/.claude/skills`)
3. **链接命令** - 可选链接到 `~/.local/bin/`

## 支持的 AI 工具

| AI 工具 | Skills 目录 | 上下文文件 |
|---------|-------------|------------|
| Claude Code | `~/.claude/skills/` | `CLAUDE.md` |
| Codex | `~/.codex/skills/` | `AGENTS.md` |

## 使用

### 创建任务环境

```bash
# 默认使用 Claude Code
tm-task fix-bug "修复登录接口的 CSRF 漏洞"

# 使用 Codex
tm-task feature "Add OAuth2" codex

# 不启动 AI，只创建 worktree
tm-task my-task "description" none
```

### 恢复工具

```bash
# 列出孤立资源
tm-recover list

# 清理孤立 worktree
tm-recover clean
```

## 工作原理

```
┌─────────────────────────────────────────┐
│  当前 Tmux Pane (工作代码)               │
│  ┌──────────────┐                       │
│  │ 你的代码      │                       │
│  │ (feat-A)     │                       │
│  └──────────────┘                       │
└─────────────────────────────────────────┘
           ↓ tm-task fix-bug "description"
           ↓
┌─────────────────────────────────────────┐
│  Tmux Pane Swap                         │
│  ┌──────────────┐  ┌──────────────┐    │
│  │ 原代码       │→ │ 新任务环境   │    │
│  │ (保存后台)   │  │ fix-bug      │    │
│  └──────────────┘  └──────────────┘    │
└─────────────────────────────────────────┘
           ↓
    AI 自动加载任务上下文
    - 任务描述
    - 项目结构
    - 分支信息
```

## 目录结构

```
tmux-git-worktree/
├── package.json             # npm 配置
├── src/install.ts           # TypeScript 安装器
├── dist/                    # 编译输出
└── skill/tmux-git-worktree/
    ├── SKILL.md             # Skill 定义
    ├── reference.md         # 详细文档
    ├── examples.md          # 使用示例
    └── scripts/
        ├── tm-task          # 主 CLI
        ├── tm-recover       # 恢复工具
        └── lib/
            ├── ai-launch.sh # AI 启动配置
            ├── skills.sh    # Skills 生成
            ├── git-worktree.sh
            ├── tmux.sh
            ├── cleanup.sh
            └── config/
                └── tm-task.conf
```

## 高级配置

### 自定义 AI 启动命令

```bash
# 使用环境变量自定义 AI 启动方式
export TM_TASK_AI_CMD_CLAUDE="claude --model opus"
export TM_TASK_AI_CMD_CODEX="codex --model gpt-4"

# 然后正常使用
tm-task my-task "description"
```

### 自定义工作目录

```bash
export TM_TASK_WORKTREE_BASE=~/dev/worktrees
tm-task my-task "description"
```

## 技术栈

- **TypeScript** - 安装器代码
- **Inquirer** - 交互式命令行
- **Bash** - 核心脚本
- **Tmux** - 窗口管理
- **Git Worktree** - 隔离环境

## 开发

```bash
# 安装依赖
npm install --ignore-scripts

# 编译
npm run build

# 本地测试
node dist/install.js
```

## License

MIT
