#!/usr/bin/env node
import { readFileSync, existsSync, mkdirSync, copyFileSync } from 'fs';
import { homedir } from 'os';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const CONFIG_DIR = `${process.env.XDG_CONFIG_HOME || `${homedir()}/.config`}/tmux-worktree`;
const CONFIG_PATH = join(CONFIG_DIR, 'config.json');
const TEMPLATE_PATH = join(__dirname, '../assets/config-template.json');

/**
 * 确保配置文件存在，若不存在则从模板自动复制
 */
export function ensureConfig() {
  if (existsSync(CONFIG_PATH)) {
    return;
  }

  // 创建配置目录
  mkdirSync(CONFIG_DIR, { recursive: true });

  // 从模板复制配置
  copyFileSync(TEMPLATE_PATH, CONFIG_PATH);
}

/**
 * 加载配置文件
 * @returns {Object} 配置对象
 */
export function loadConfig() {
  ensureConfig();

  try {
    const content = readFileSync(CONFIG_PATH, 'utf-8');
    return JSON.parse(content);
  } catch (e) {
    console.error(`Error: Failed to parse config file at ${CONFIG_PATH}`);
    console.error(e.message);
    process.exit(1);
  }
}

/**
 * 获取 AI 工具列表（用于 query-config 命令）
 * @returns {Object} { default_ai, ai_tools: [{name, description}, ...] }
 */
export function getAiToolsInfo() {
  const config = loadConfig();
  const aiTools = Object.entries(config.ai_tools || {}).map(([name, tool]) => ({
    name,
    description: tool.description || name
  }));

  return {
    default_ai: config.default_ai || aiTools[0]?.name || null,
    ai_tools: aiTools
  };
}

export { CONFIG_PATH };
