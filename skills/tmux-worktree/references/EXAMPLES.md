# Usage Examples

## Creating a new worktree session

```
User: I need to add OAuth2 login to the app

Agent: 1. Generates structured prompt following the template:

       # Task: Add OAuth2 Login

       ## Context
       - **Branch**: feature/add-oauth2-login
       - **Worktree**: .worktrees/add-oauth2-login

       ## Objective
       Implement OAuth2 authentication flow...

       ## Original Request
       用户要求添加 OAuth2 登录功能...

       ## Constraints
       - 工作目录限制在当前 worktree 内
       - 完成后更新 .tmux-worktree/progress.md 记录结果
       - 遵循项目的代码规范

       ## Success Criteria
       - 用户可以使用 Google 账号登录
       - 用户可以使用 GitHub 账号登录

       2. Creates worktree at `.worktrees/add-oauth2-login`
       3. Creates branch `feature/add-oauth2-login`
       4. Opens tmux window "add-oauth2-login"
       5. Saves prompt to `.tmux-worktree/prompt.md`
       6. Launches: `cat .tmux-worktree/prompt.md | claude`

Result: Fresh tmux window with Claude ready, prompt persisted.
```

## Querying worktree status

```
User: Show me all my active worktrees

Output:
Branch                          Worktree             Changes  Status
-------                         -------              ------  ------
feature/add-oauth2-login        add-oauth2-login     3        In Progress
feature/fix-login-bug-2         fix-login-bug-2      1        Completed
feature/refactor-auth           refactor-auth        0        -
```

## Viewing AI results

```
User: What were the results from the OAuth2 work?

Agent: Reads .worktrees/add-oauth2-login/.tmux-worktree/progress.md

# Task Progress

## Status
**Completed**

## Final Summary

### Overview
Implemented OAuth2 authentication with Google and GitHub providers.

### Changes Made
- Added Google OAuth2 provider
- Created /auth/callback endpoint
- Integrated with existing session management

### Files Modified
- src/auth/oauth.ts (new)
- src/auth/session.ts
- package.json (added dependencies)

### Testing
- Manual testing with Google and GitHub
- All OAuth flows working correctly
```

## Cleanup workflow

```
User: Clean up my completed worktrees

Agent: Runs `tmux-worktree list` first

Output:
Branch                          Worktree             Changes  Status
-------                         -------              ------  ------
feature/add-oauth2-login        add-oauth2-login     0        Completed

Agent: Offers to show progress.md before cleanup
       Runs `tmux-worktree cleanup`

Remove feature/add-oauth2-login? [y/N]: y
✓ Removed feature/add-oauth2-login
```
