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
- **Open finding (not verified):** that token is set in `claude-bridge.service`; the running `hermes-gateway` process (the dispatcher, whose env the worker inherits) does **not** have it. `~/.claude-kanban/.credentials.json` is dated 2026-08-22 and its `expiresAt` is in the past. Last recorded worker run was 2026-10-31 and succeeded, so some path works (e.g. CLI refresh, or other env), but it has not been traced. Check before the first dispatch; if auth fails, fix is to pass the token to the worker env, not to merge config dirs.
- Model choice (this patch) does not affect auth.

## Status
fork-only, new 2026-11-13.

## Last verified
2026-11-13 on `main` (post 10-13 cutover); argv logic checked by replica, not by a live dispatch.

## Original commit
`013cdb5327`
