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
fork-only

## Last verified
2026-06-07 against upstream commit `1fc7bdc5e64e052bc61d3ddb9e6f96cf6c7461dc`

## Original commit
`95ca99a47` — `feat(kanban): child tasks inherit parent workspace`
