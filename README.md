# Tmux Git Worktree - Claude Code Skill

基于 Tmux + Git Worktree 的上下文交换工作流。

## 安装

```bash
npm install @ekko.tmux-git-worktree
```

安装时会启动 **TypeScript 交互式安装器**：

1. 选择要配置的 AI 工具
   - Claude Code (`~/.claude/skills`)
   - Codex (`~/.codex/skills`)

2. 为每个 AI 工具选择安装位置
   - Project: `./{ai-tool}/skills/`
   - User: `~/{ai-tool}/skills`
   - Custom: 自定义路径

3. 是否链接命令到 `~/.local/bin/`

**支持的 AI 工具和 Skills 目录：**

| AI 工具 | Project Level | User Level |
|---------|---------------|------------|
| Claude Code | `./.claude/skills/` | `~/.claude/skills` |
| Codex | `./.codex/skills` | `~/.codex/skills` |

## 使用

```bash
tm-task <branch-name> <task-description> [ai-command]

# Examples:
tm-task fix-bug "修复登录接口的 CSRF 漏洞"
tm-task feature "Add OAuth2" codex
```

## 目录结构

```
tmux-git-worktree/         (npm 项目根)
├── package.json             (npm 配置)
├── tsconfig.json            (TS 配置)
├── README.md
├── src/                     (TypeScript 源码)
│   └── install.ts          (交互式安装器)
├── dist/                    (编译输出 - gitignore)
└── skill/                   (skill 内容 - 安装到 .claude/skills/)
    └── tmux-git-worktree/
        ├── SKILL.md
        ├── reference.md
        ├── examples.md
        └── scripts/
            ├── tm-task
            ├── tm-recover
            └── lib/
                ├── tmux.sh
                ├── git-worktree.sh
                ├── skills.sh
                ├── cleanup.sh
                └── config/
                    ├── tm-task.conf
                    └── ai-tools.json (自动生成)
```

## 开发

```bash
# 编译 TypeScript
npm run build

# 本地测试
npm run build && node dist/install.js
```

## 技术栈

- **TypeScript** - 安装器代码
- **Inquirer** - 交互式命令行界面
- **Chalk** - 终端颜色输出
- **Ora** - 加载动画
- **fs-extra** - 文件系统操作

MIT License
