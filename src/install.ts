import inquirer from 'inquirer';
import chalk from 'chalk';
import ora from 'ora';
import path from 'path';
import fs from 'fs-extra';
import os from 'os';

// Types
interface InstallLocation {
  scope: 'project' | 'user' | 'custom';
  customPath?: string;
}

interface AIToolConfig {
  name: string;
  value: string;
  projectDir: string;
  userDir: string;
}

interface InstallPlan {
  aiTool: string;
  location: InstallLocation;
  targetPath: string;
}

// AI Tool configurations
const AI_TOOLS_CONFIG: AIToolConfig[] = [
  {
    name: 'Claude Code',
    value: 'claude',
    projectDir: '.claude/skills',
    userDir: '.claude/skills',
  },
  {
    name: 'Codex',
    value: 'codex',
    projectDir: '.codex/skills',
    userDir: '.codex/skills',
  },
];

// Logger
const log = {
  info: (msg: string) => console.log(chalk.green('[tmux-git-worktree]'), msg),
  warn: (msg: string) => console.log(chalk.yellow('[tmux-git-worktree]'), msg),
  error: (msg: string) => console.log(chalk.red('[tmux-git-worktree]'), msg),
};

// Detect if we're in a project directory
function isProjectDir(): boolean {
  const cwd = process.cwd();
  return fs.existsSync(path.join(cwd, '.git')) ||
         fs.existsSync(path.join(cwd, 'package.json'));
}

// Get install path for AI tool
function getInstallPath(aiTool: AIToolConfig, location: InstallLocation): string {
  const cwd = process.cwd();
  const home = os.homedir();

  switch (location.scope) {
    case 'project':
      return path.join(cwd, aiTool.projectDir);
    case 'user':
      return path.join(home, aiTool.userDir);
    case 'custom':
      return location.customPath || '';
    default:
      return path.join(home, aiTool.userDir);
  }
}

// Copy skill files to destination
async function copySkillFiles(destPath: string, aiTools: string[]): Promise<void> {
  const skillName = 'tmux-git-worktree';
  const skillDestPath = path.join(destPath, skillName);

  await fs.ensureDir(destPath);

  const packageRoot = path.join(__dirname, '..');
  const skillSourcePath = path.join(packageRoot, 'skill', 'tmux-git-worktree');

  await fs.copy(skillSourcePath, skillDestPath, {
    overwrite: false,
    errorOnExist: false,
  });

  // Make scripts executable
  const scriptDir = path.join(skillDestPath, 'scripts');
  const libDir = path.join(scriptDir, 'lib');

  for (const file of await fs.readdir(scriptDir)) {
    const filePath = path.join(scriptDir, file);
    if ((await fs.stat(filePath)).isFile()) {
      await fs.chmod(filePath, 0o755);
    }
  }

  for (const file of await fs.readdir(libDir)) {
    const filePath = path.join(libDir, file);
    if ((await fs.stat(filePath)).isFile()) {
      await fs.chmod(filePath, 0o755);
    }
  }

  // Create AI tool config
  await createAIConfig(skillDestPath, aiTools);
}

// Create AI tool configuration
async function createAIConfig(skillPath: string, aiTools: string[]): Promise<void> {
  const configPath = path.join(skillPath, 'scripts', 'lib', 'config', 'ai-tools.json');
  await fs.writeJson(configPath, { enabledAITools: aiTools }, { spaces: 2 });
}

// Link commands to ~/.local/bin
async function linkCommands(skillPath: string): Promise<void> {
  const binDir = path.join(os.homedir(), '.local', 'bin');
  await fs.ensureDir(binDir);

  const tmTaskPath = path.join(skillPath, 'scripts', 'tm-task');
  const tmRecoverPath = path.join(skillPath, 'scripts', 'tm-recover');

  await fs.remove(path.join(binDir, 'tm-task'));
  await fs.remove(path.join(binDir, 'tm-recover'));

  await fs.symlink(tmTaskPath, path.join(binDir, 'tm-task'));
  await fs.symlink(tmRecoverPath, path.join(binDir, 'tm-recover'));
}

// Prompt for installation location for a specific AI tool
async function promptForLocation(aiTool: AIToolConfig): Promise<InstallLocation> {
  const choices = [
    {
      name: `User-level (~/${aiTool.userDir})`,
      value: 'user',
      short: 'User',
    },
  ];

  if (isProjectDir()) {
    choices.unshift({
      name: `Project-level (./${aiTool.projectDir})`,
      value: 'project',
      short: 'Project',
    });
  }

  choices.push({
    name: 'Custom path',
    value: 'custom',
    short: 'Custom',
  });

  const { scope } = await inquirer.prompt([
    {
      type: 'list',
      name: 'scope',
      message: `Install for ${aiTool.name}:`,
      choices,
    },
  ]);

  if (scope === 'custom') {
    const { customPath } = await inquirer.prompt([
      {
        type: 'input',
        name: 'customPath',
        message: 'Enter custom installation path:',
        default: path.join(os.homedir(), aiTool.userDir),
        filter: (input) => input.replace(/^~/, os.homedir()),
      },
    ]);
    return { scope: 'custom', customPath };
  }

  return { scope };
}

// Main install function
export async function install(): Promise<void> {
  console.log('');
  console.log(chalk.blue('======================================'));
  console.log(chalk.blue('  tmux-git-worktree Skill Installer'));
  console.log(chalk.blue('======================================'));
  console.log('');

  // Step 1: Select AI tools to configure
  const { aiTools } = await inquirer.prompt([
    {
      type: 'checkbox',
      name: 'aiTools',
      message: 'Select AI tools to configure:',
      choices: AI_TOOLS_CONFIG.map((tool) => ({
        name: tool.name,
        value: tool.value,
        checked: tool.value === 'claude',
      })),
      validate: (answer) => {
        if (answer.length < 1) {
          return 'You must choose at least one AI tool.';
        }
        return true;
      },
    },
  ]);

  console.log('');
  log.info('Configure installation locations for each AI tool:');
  console.log('');

  // Step 2: For each AI tool, ask for installation location
  const installPlan: InstallPlan[] = [];

  for (const toolValue of aiTools) {
    const toolConfig = AI_TOOLS_CONFIG.find((t) => t.value === toolValue)!;
    const location = await promptForLocation(toolConfig);
    const targetPath = getInstallPath(toolConfig, location);

    installPlan.push({
      aiTool: toolValue,
      location,
      targetPath,
    });
  }

  // Step 3: Link commands
  const { linkCommands: linkCmds } = await inquirer.prompt([
    {
      type: 'confirm',
      name: 'linkCommands',
      message: 'Link commands to ~/.local/bin?',
      default: true,
    },
  ]);

  // Execute installation
  console.log('');
  const spinner = ora('Installing skill...').start();

  try {
    // Install to each configured location
    for (const plan of installPlan) {
      await copySkillFiles(plan.targetPath, aiTools);

      if (linkCmds) {
        // Link commands from the first installation location
        await linkCommands(path.join(plan.targetPath, 'tmux-git-worktree'));
        linkCmds; // Only link once
        break;
      }
    }

    // Create worktree base directory
    const worktreeBase = process.env.TM_TASK_WORKTREE_BASE ||
                        path.join(os.homedir(), '.local', 'tmux-git-worktrees');
    await fs.ensureDir(worktreeBase);

    spinner.succeed();

    // Summary
    console.log('');
    log.info('Installation complete!');
    console.log('');

    for (const plan of installPlan) {
      const toolConfig = AI_TOOLS_CONFIG.find((t) => t.value === plan.aiTool)!;
      console.log(chalk.green(`[${toolConfig.name}]`), path.join(plan.targetPath, 'tmux-git-worktree'));
    }

    console.log('');
    console.log(chalk.green('Enabled AI tools:'), aiTools.join(', '));

    if (linkCmds) {
      console.log(chalk.green('Commands linked to:'), path.join(os.homedir(), '.local', 'bin'));
    }

    console.log('');
    console.log('Usage:');
    console.log('  tm-task <branch-name> <task-description> [ai-command]');
    console.log('');
    console.log('Examples:');
    console.log('  tm-task fix-bug "修复登录接口的 CSRF 漏洞"');
    console.log('  tm-task feature "Add OAuth2" codex');
    console.log('');

    if (linkCmds) {
      const binDir = path.join(os.homedir(), '.local', 'bin');
      const pathVar = process.env.PATH || '';
      if (!pathVar.includes(binDir)) {
        log.warn(`Make sure ${binDir} is in your PATH`);
      }
    }

  } catch (error) {
    spinner.fail();
    log.error(String(error));
    process.exit(1);
  }
}

// Run install
install().catch(console.error);
