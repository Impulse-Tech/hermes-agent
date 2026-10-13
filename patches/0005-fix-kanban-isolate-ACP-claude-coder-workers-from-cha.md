# 0005 — fix(kanban): isolate ACP claude-coder workers from chat session credentials

## Intent
Kanban `claude-coder` workers (spawned as ACP subprocesses, see patch `0003`) and the Hermes chat session's own `claude` CLI both read/write the same `~/.claude/.credentials.json`. When both processes refresh a near-expiry OAuth token at the same time, the race can zero out both tokens, wiping Yang's Max login. This happened 2026-07-07.

Fix: when `_default_spawn` spawns a `claude`/`claude-code` ACP command, it now sets `CLAUDE_CONFIG_DIR=~/.claude-kanban` in the child's env (via `env.setdefault`, so an explicit profile override still wins). This points the kanban worker's `claude` CLI at an isolated credentials file, separate from the chat session's `~/.claude/`.

## Where it goes
- `hermes_cli/kanban_db.py` — inside `_default_spawn`, in the ACP branch (Branch 1), right after the `-p`/`--print` auto-injection for `claude`/`claude-code` basenames.

## Requires (one-time, manual)
`~/.claude-kanban/` must exist and contain valid credentials before any kanban `claude-coder` worker can run:
```
mkdir -p ~/.claude-kanban
CLAUDE_CONFIG_DIR=~/.claude-kanban claude auth login
```
This is a separate PKCE login tied to the same Max account, writing to an isolated `~/.claude-kanban/.credentials.json`.

## Skip when
Upstream adds ACP support to kanban with its own credential-isolation mechanism, or the fork moves off shared `~/.claude/` credentials for ACP spawns generally.

## Smoke test
1. Confirm `~/.claude-kanban/.credentials.json` exists and is valid (`CLAUDE_CONFIG_DIR=~/.claude-kanban claude -p "say hi"`).
2. Dispatch a kanban task to a profile with `acp_command: claude`.
3. While the worker is running, use the Hermes chat session's own Claude Code path (or trigger a token refresh) and confirm `~/.claude/.credentials.json` is untouched.
4. Confirm the worker's own `~/.claude-kanban/.credentials.json` is the one used (check worker log / `ps` env, or that revoking one doesn't affect the other).

## Status
fork-only

## Last verified
2026-07-08 against upstream commit `9f8060919eac6bc1cdfff7a501806f504e41680d`

## Original commit
`b2e27e190` — `fix(kanban): isolate ACP claude-coder workers from chat session credentials`
