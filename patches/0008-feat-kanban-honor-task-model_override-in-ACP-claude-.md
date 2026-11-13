# 0008 — feat(kanban): honor task `model_override` in the ACP `claude` branch

## Why (background, 2026-11-13)
- `kanban-claude-coder` is **not** a Hermes agent session. Patch 0003 makes `_default_spawn` run a headless `claude -p ... -- "<task body>"` subprocess when the profile sets `kanban.acp_command: claude` (name is a misnomer; no ACP protocol is spoken).
- The profile's `model.default` is **ignored** by that path. The model is whatever `--model` is in `kanban.acp_args`, else the Claude CLI's own default. Until today no `--model` was set, so workers ran on the CLI default (worker sessions in `~/.claude-kanban/projects` show Sonnet 4.6, one Sonnet 5).
- `hermes kanban create --model X` stores `task.model_override`, but the dispatcher only consumed it in the native-worker branch (`-m`), never in the ACP branch. So the old "L/XL tickets use opus-4-7" rule (flip profile model before dispatch, restore after) never changed the real model.

## Intent
Tiered models by ticket size without flipping config:
- Profile `claude-coder` default: `kanban.acp_args` contains `--model claude-sonnet-5-5` (small/medium tickets).
- L/XL tickets (and their reviews, so worker/reviewer models match): `hermes kanban create ... --assignee claude-coder --model claude-opus-5-5`.

## Where it goes
`hermes_cli/kanban_db_dispatch.py`, `_default_spawn` ACP branch, inside the `claude`/`claude-code` basename block, right after the `CLAUDE_CONFIG_DIR` default. If `task.model_override` is set: remove an existing `--model <v>` pair from `acp_cmd`, append `--model <override>`. Only applies to `claude`-style commands (other ACP tools may not use `--model`).

## Skip when
Upstream's ACP/kanban spawn honors `model_override` natively, or patch 0003 is dropped.

## Smoke test (no model call)
Build argv for a task with and without `model_override` and check exactly one `--model` appears, last before `--`:
- no override: `claude -p --dangerously-skip-permissions --model claude-sonnet-5-5 -- <body>`
- override opus: `claude -p --dangerously-skip-permissions --model claude-opus-5-5 -- <body>`
First real dispatch should also be confirmed from `~/.claude-kanban/projects/*/*.jsonl` (`"model"` field of the newest session).

## Credential / config isolation (patch 0005), and the shared token
- 0005 sets `CLAUDE_CONFIG_DIR=~/.claude-kanban` for worker processes. That separates the worker's `.claude.json` (project trust, history), `projects/`, `sessions/`, and `.credentials.json` from the chat side's `~/.claude`. Purpose: stop two Claude processes racing to refresh/rewrite one credentials file (the 07-08 incident), and contain crashes.
- It is isolation of *files*, not of *accounts*. Both sides are the same Max subscription.
- Using the same long-lived `CLAUDE_CODE_OAUTH_TOKEN` for both is compatible with isolation: an env-var token is not written to the config dir, so no refresh race.
- **Resolved 2026-11-13 (see next section):** the token was not reaching the worker; fixed with a wrapper script, verified by two real dispatches.
- Model choice (this patch) does not affect auth.

## Token wrapper (claude-coder auth), added 2026-11-13

### Problem
`~/.claude-kanban/.credentials.json` expired 2026-08-22, so a worker relying on it would 401. The fix is to use the long-lived `CLAUDE_CODE_OAUTH_TOKEN` (same Max subscription token as `claude-bridge.service`). Getting it into the worker env was not straightforward:
- Putting it in `~/.hermes/.env` loads it into the gateway's `os.environ`, but the dispatcher then calls `strip_launch_profile_env` (`tools/environments/local.py:458`) for routed profiles. That deletes every key supplied by the launch profile's `.env`, on the assumption the child re-reads its own profile `.env`. A native Hermes worker does; a plain `claude -p` process does not.
- Putting it in `~/.hermes/profiles/claude-coder/.env` alone does nothing either, since the strip runs after the profile-scope block (`kanban_db_dispatch.py` ~2882) and nothing re-adds it.
- The `.credentials.json` route is outside the strip (it is a file, not env), but its token is expired and it reintroduces refresh-token rotation.
- Stripping is by design (profile isolation), not aimed at this worker. Do not weaken it globally.

### Solution: wrapper as `kanban.acp_command`
- `patches/support/claude-coder-wrapper.sh` (tracked in the fork, commit `6493c95514`).
- Installed as `~/.hermes/profiles/claude-coder/bin/claude`, a symlink to the tracked file. `kanban.acp_command` in the profile `config.yaml` (untracked) points at that path.
- It reads `CLAUDE_CODE_OAUTH_TOKEN` from `~/.hermes/profiles/claude-coder/.env` (override: `CLAUDE_CODER_ENV_FILE` -> `CLAUDE_CODER_ENV_FILE`), exports it, and `exec`s the real CLI. It runs inside the worker process, after the dispatcher's stripping, so the token survives. Token goes in env only, never argv (`ps`-visible), never printed.
- Real CLI lookup order: `$CLAUDE_REAL_BIN`, newest `~/.nvm/versions/node/*/bin/claude`, first non-wrapper `claude` on `PATH`. No hardcoded Node version. Exits 127 if none found.
- **The wrapper must be named `claude`** (symlink name counts; the dispatcher checks the unresolved basename at `kanban_db_dispatch.py` ~2954). Any other name skips the `-p`, `CLAUDE_CONFIG_DIR` and `--model` override handling (0008).
- The token lives only in `claude-coder`'s `.env`, not in `~/.hermes/.env`.

### Does CLAUDE_CONFIG_DIR (0005) still matter?
Not for auth: an env token is never written to the config dir, so no refresh race. Kept for isolating worker session history, project trust and `.claude.json` from chat `~/.claude`.

### Setup from scratch
1. Add `CLAUDE_CODE_OAUTH_TOKEN=<token>` to `~/.hermes/profiles/claude-coder/.env` (mode 600).
2. `mkdir -p ~/.hermes/profiles/claude-coder/bin && ln -sf <fork>/patches/support/claude-coder-wrapper.sh ~/.hermes/profiles/claude-coder/bin/claude`
3. Set `kanban.acp_command` to that absolute path in the profile `config.yaml`.
4. Verify without a model call: `~/.hermes/profiles/claude-coder/bin/claude auth status` with the token unset in the caller -> `loggedIn: true, authMethod: oauth_token`.

### Verification (2026-11-13, real dispatches)
- `t_3630dbb2`, no override: ran on `claude-sonnet-5-5`, 14s, no auth error. `.credentials.json` untouched since Aug 22, so auth came from the token.
- `t_42e0750b`, `--model claude-opus-5-5`: ran on `claude-opus-5-5`; confirms the 0008 override.
- The worker's shell showed the token empty; Claude Code does not pass that variable to tools it runs, so this is expected.

### Caveats
- Profile `config.yaml`, `.env` and the symlink are outside the repo; a git revert does not undo them.
- The stale `~/.claude-kanban/.credentials.json` was intentionally left in place.
- Token expires ~2027-09-04 (see the bridge's setup-token); update the profile `.env` when rotated.

## Status
fork-only, new 2026-11-13.

## Last verified
2026-11-13 on `main` (post 10-13 cutover); argv logic checked by replica; live dispatches t_3630dbb2 (Sonnet) and t_42e0750b (Opus) passed.

## Original commit
`013cdb5327`
