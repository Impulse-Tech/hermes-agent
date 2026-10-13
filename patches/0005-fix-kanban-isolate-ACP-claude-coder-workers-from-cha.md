# 0005 — fix(kanban): isolate ACP claude-coder workers from chat session credentials

## Intent
Kanban `claude-coder` workers (spawned as ACP subprocesses, see patch `0003`) and the Hermes chat session's own `claude` CLI both read/write the same `~/.claude/.credentials.json`. When both processes refresh a near-expiry OAuth token at the same time, the race can zero out both tokens, wiping Yang's Max login. This happened 2026-07-07.

Fix: when `_default_spawn` spawns a `claude`/`claude-code` ACP command, it now sets `CLAUDE_CONFIG_DIR=~/.claude-kanban` in the child's env (via `env.setdefault`, so an explicit profile override still wins). This points the kanban worker's `claude` CLI at an isolated credentials file, separate from the chat session's `~/.claude/`.

**Update 2026-09-04 — auth-race rationale superseded, isolation retained for other reasons.** Both `~/.claude/.credentials.json` (chat) and `~/.claude-kanban/.credentials.json` (kanban) independently zeroed out from failed refreshes in late Aug/early Sep 2026 (unrelated to each other — no concurrent-refresh race, just normal rotating-token fragility on a headless box). Fix: `claude setup-token` now generates a long-lived (1yr) `CLAUDE_CODE_OAUTH_TOKEN`, set as an `Environment=` var on `hermes-gateway.service` (see [[project-claude-max-oauth-setup-token-fix]]). Since kanban workers spawn via `env = dict(os.environ)` from the gateway process, they inherit this token automatically. Verified empirically (2026-09-04): `CLAUDE_CODE_OAUTH_TOKEN` takes precedence over `CLAUDE_CONFIG_DIR`'s `.credentials.json` — a worker spawned with both set authenticates via the env-var token and never touches either credentials file. This means the original race condition this patch fixed can no longer occur (neither path refreshes anymore), **but the `CLAUDE_CONFIG_DIR` isolation itself is still worth keeping** for unrelated reasons: it keeps kanban's automated session history / project trust state / shell snapshots out of the interactive chat's `--continue`/`--resume` list, and contains blast radius if a worker crashes mid-write. Do not remove the `env.setdefault("CLAUDE_CONFIG_DIR", ...)` line on the assumption the race is the only reason it exists.

## Where it goes
- `hermes_cli/kanban_db_dispatch.py` — moved here from `kanban_db.py` by the 2026-10-13 upstream module split (see [[0003]]). Inside `_default_spawn`, in the ACP branch (Branch 1), right after the `-p`/`--print` auto-injection for `claude`/`claude-code` basenames.

## Requires (one-time, manual)
`~/.claude-kanban/` must exist and contain valid credentials before any kanban `claude-coder` worker can run:
```
mkdir -p ~/.claude-kanban
CLAUDE_CONFIG_DIR=~/.claude-kanban claude auth login
```
This is a separate PKCE login tied to the same Max account, writing to an isolated `~/.claude-kanban/.credentials.json`.

**As of 2026-09-04, this is no longer strictly required** — `CLAUDE_CODE_OAUTH_TOKEN` on the gateway process authenticates the worker before it ever looks at this file (see Update note above). Kept valid anyway for defense-in-depth in case the env var is ever missing from a spawn.

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
2026-10-13 against upstream commit `9e041a7428392b01b989ef9cecf46a5f96be12fc` — `git am` failed (anchor moved to `kanban_db_dispatch.py`, see [[0003]]); hand-ported onto the same ACP branch patch 0003 landed there.

## Original commit
`b2e27e190` — `fix(kanban): isolate ACP claude-coder workers from chat session credentials` (hand-ported again as `97f7ba48f3` on 2026-10-13)
