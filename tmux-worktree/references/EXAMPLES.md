# Usage Examples

## Creating a new worktree session

```
User: I need to add OAuth2 login to the app

Agent: Creates worktree at `.worktrees/add-oauth2-login`
       Creates branch `feature/add-oauth2-login`
       Opens tmux window "add-oauth2-login"
       Launches: `claude "Add OAuth2 login..."`

Result: Fresh tmux window with Claude ready.
```

## Querying worktree status

```
User: Show me all my active worktrees

Output:
add-oauth2-login    .worktrees/add-oauth2-login   3    ✓ Added OAuth flow...
fix-login-bug       .worktrees/fix-login-bug-2    1    ✓ Fixed password val...
refactor-auth       .worktrees/refactor-auth      0    -
```

## Viewing AI results

```
User: What were the results from the OAuth2 work?

Agent: Reads .worktrees/add-oauth2-login/RESULT.md

# OAuth2 Implementation Summary

## Changes Made
- Added Google OAuth2 provider
- Created /auth/callback endpoint

## Files Modified
- src/auth/oauth.ts (new)
- src/auth/session.ts
```

## Cleanup workflow

```
User: Clean up my completed worktrees

Remove feature/add-oauth2-login? (already merged) [y/N]: y
✓ Removed feature/add-oauth2-login
```
