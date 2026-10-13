# 0007 — fix(kanban): use `--` end-of-options marker before ACP prompt

## Intent
`_default_spawn`'s ACP branch (patch [[0003]]) builds `acp_cmd = [acp_command, ...acp_args, "-p", task.body]` and hands it straight to `subprocess.Popen`. `task.body` is arbitrary text — a kanban task description, potentially sourced from Discord or another untrusted caller. If a task body happens to start with `-` (e.g. a title/body starting with a bullet-dash, or deliberately crafted), the ACP CLI's own argument parser could interpret it as a flag instead of positional prompt text (argv flag-smuggling).

Fix: insert a literal `"--"` end-of-options marker immediately before the prompt string, so everything after it is treated as a positional argument by any getopt/argparse/commander-style CLI (this covers `claude`, `codex`, and other common ACP tools).

Found by the repo's automated security-review hook while hand-porting patch 0003 onto the 2026-10-13 upstream-sync branch (the original patch never had this, dating back to 2026-05-31 — predates the hook).

## Where it goes
- `hermes_cli/kanban_db_dispatch.py` — inside `_default_spawn`'s ACP branch, immediately before `acp_cmd = _restart_safe_worker_argv(task, acp_cmd)`. Was: `acp_cmd.append(acp_prompt)`. Now: `acp_cmd.extend(["--", acp_prompt])`.

## Skip when
Patch 0003 is itself dropped (upstream adds native ACP kanban support with its own argv handling).

## Smoke test
1. Create a kanban task with a body starting with a dash, e.g. `hermes kanban create --title t --body "-rf this is not a flag"`.
2. Dispatch it to a profile with `acp_command: claude`.
3. Confirm the worker log shows the ACP tool received the full body text as its prompt, not an argument-parsing error or unexpected flag behavior.

## Status
fork-only — new 2026-10-13, no upstream equivalent expected (ACP kanban spawning itself is fork-only).

## Last verified
2026-10-13 against upstream commit `9e041a7428392b01b989ef9cecf46a5f96be12fc` — applied directly alongside the 0003 hand-port, same commit chain.

## Original commit
`f12d29fdc6` — `fix(kanban): use -- end-of-options marker before ACP prompt to prevent argv flag injection from task body`
