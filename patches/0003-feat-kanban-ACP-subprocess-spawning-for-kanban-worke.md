# 0003 — feat(kanban): ACP subprocess spawning for kanban workers

## Intent
Allow kanban workers to be spawned as ACP (Agent Client Protocol) subprocesses, not just inline within the gateway. This is what enables Claude Code, Codex, OpenCode etc. to act as kanban workers via their respective CLI bridges. Without this, kanban only works with the in-process Hermes agent.

## Where it goes
- `hermes_cli/kanban_db.py` — the worker resolution path. Adds a branch: if the profile specifies `acp_command`, spawn that command as a subprocess instead of dispatching to the in-process agent.
- `hermes_cli/profiles.py` — profile schema extension to recognize the `acp_command` field and validate it.

## Skip when
Upstream adds ACP support to kanban. Watch for any commit to `hermes_cli/kanban_db.py` or `hermes_cli/profiles.py` adding subprocess/ACP spawning logic.

## Smoke test
1. Configure a profile with `acp_command` (e.g. `claude -p` or `codex -q`).
2. Create a kanban task and dispatch to that profile: `hermes kanban dispatch <task-id> --profile <name>`.
3. Verify the worker runs as a subprocess (visible in `ps`, not as a thread of the gateway process).
4. Verify task completes and result is written back to the kanban DB.

## Status
fork-only

## Last verified
2026-06-07 against upstream commit `1fc7bdc5e64e052bc61d3ddb9e6f96cf6c7461dc`

## Original commit
`8ae8f4bfa` — `feat(kanban): ACP subprocess spawning for kanban workers`
