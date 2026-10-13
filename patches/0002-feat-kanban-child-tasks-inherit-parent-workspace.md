# 0002 — feat(kanban): child tasks inherit parent workspace

## Intent
When a kanban task spawns child sub-tasks (via the dispatcher or `delegate_task`), the child should run in the same workspace directory as the parent task. Without this, children spawn in the gateway's CWD and lose project context.

## Where it goes
- `hermes_cli/kanban.py` — the task-creation / spawn flow that builds a new task record. Look for where the workspace field is set on a new child task; the fix copies the parent's workspace if no override is given.

## Skip when
Upstream adds inheritance natively. Watch for any commit to `hermes_cli/kanban.py` adding a `parent_workspace` or `workspace_inheritance` mechanism.

## Smoke test
1. Create a parent kanban task with a specific workspace: `hermes kanban create --title "parent" --workspace /tmp/test-ws`.
2. Dispatch the parent; have the parent worker create a child task with no explicit workspace.
3. Verify child task's workspace equals parent's: `hermes kanban get <child-id>` should show `workspace: /tmp/test-ws`.

## Status
**superseded-by-upstream, dropped 2026-10-13** — upstream now has native, more sophisticated workspace inheritance in `hermes_cli/kanban_db_graph.py` (`_insert_decomposed_child`): per-child `workspace_kind`/`workspace_path` override wins, else inherits the root's kind; path inherits only when kinds match, and NEVER for `worktree` kind (the fork's old patch would have handed every decomposed sibling the same worktree checkout — a concurrent-dispatch race this patch never accounted for). The "Skip when" condition on this patch fired exactly as designed. Do not re-apply; file kept for historical reference only.

## Last verified
2026-10-13 against upstream commit `9e041a7428392b01b989ef9cecf46a5f96be12fc` — confirmed superseded, `git am` fails (anchor function moved/restructured) and no longer needed. See `hermes_cli/kanban_db_graph.py` lines ~169-199 for the replacement.

## Original commit
`95ca99a47` — `feat(kanban): child tasks inherit parent workspace`
