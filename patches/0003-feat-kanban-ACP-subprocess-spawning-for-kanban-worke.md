# 0003 — feat(kanban): ACP subprocess spawning for kanban workers

## Intent
Allow kanban workers to be spawned as ACP (Agent Client Protocol) subprocesses, not just inline within the gateway. This is what enables Claude Code, Codex, OpenCode etc. to act as kanban workers via their respective CLI bridges. Without this, kanban only works with the in-process Hermes agent.

## Where it goes
- `hermes_cli/kanban_db_dispatch.py` — moved here from `kanban_db.py` by an upstream module split (2026-10-13 sync); `_default_spawn` now lives at the end of this file. Branch 1 (ACP) sits right after `env.pop("HERMES_TUI", None)`, before `cmd = _worker_argv(...)` (Branch 2, native).
- `hermes_cli/profiles.py` — `_read_profile_kanban_acp()`, added right after `_read_config_model()`; uses the module's existing `_cached_profile_read()` / `read_user_config_raw()` helpers for consistency with the current file's style (these didn't exist at the patch's original 2026-05-31 vintage).

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
2026-10-13 against upstream commit `9e041a7428392b01b989ef9cecf46a5f96be12fc` — `git am` failed outright (`_default_spawn` moved modules); hand-ported. Upstream had since split `kanban_db.py` into several files (`kanban_db_dispatch.py`, `kanban_db_workspace.py`, `kanban_db_graph.py`, `kanban_resume_guard.py`) and extracted the native-worker command-building into `_worker_argv()` + `_restart_safe_worker_argv()` (systemd-scope safety for long-lived workers) + `_open_worker_log()` (shared log setup, already de-duplicated — the fork's old de-dup note from 2026-08-01 is now moot, upstream did it natively). The ACP branch now also runs through `_restart_safe_worker_argv()` and `systemd_user_bus_env()` like the native branch does, so an ACP worker survives a managed-gateway restart the same way a native one does (the original patch predated that safety mechanism and would have regressed it). Patch 0007 layers an argv-injection fix (`--` end-of-options marker) on top of this same branch.

## Original commit
`8ae8f4bfa` — `feat(kanban): ACP subprocess spawning for kanban workers` (hand-ported again as `05c3c58335` on 2026-10-13)
