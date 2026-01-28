# SKILL 工作流重构设计

**日期:** 2026-01-25

## 概述

将 SKILL 文件与配置管理解耦，配置对 AI 完全不可见，所有配置相关操作由脚本处理。

## 核心变更

### 1. 新增 `query-config` 命令

**文件:** `scripts/query-config.js`

**功能:** 输出 JSON 格式的 AI 工具配置信息

**输出格式:**
```json
{
  "default_ai": "claude",
  "ai_tools": [
    { "name": "claude", "description": "Anthropic Claude AI assistant" },
    { "name": "cursor", "description": "Cursor AI IDE integration" }
  ]
}
```

### 2. 配置自动复制机制

所有命令（create, setup, list, cleanup, query-config）在执行前：
- 检查 `~/.config/tmux-worktree/config.json` 是否存在
- 若不存在，自动从 `./assets/config-template.json` 复制
- 静默处理，无需用户干预

### 3. SKILL.md 工作流变更

**移除内容:**
- 配置文件结构说明
- 手动复制配置指令
- 配置路径和字段描述

**新工作流:**
1. 调用 `tmux-worktree query-config` 获取工具列表
2. 若只有一个 AI 工具 → 自动使用
3. 若有多个 AI 工具 → 使用 `AskUserQuestion` 让用户选择
4. 继续执行 create/setup 等命令

## 实现步骤

1. 创建 `scripts/query-config.js`
2. 创建配置管理模块 `scripts/lib/config.js`
3. 更新 `index.js` 添加 query-config 命令
4. 更新所有现有命令使用新的配置管理模块
5. 重写 `SKILL.md`
