# Local Patches (Impulse-Tech fork)

This directory tracks **local-only patches** that must be preserved across upstream syncs from `NousResearch/hermes-agent` → `Impulse-Tech/hermes-agent`. Without this tracking, every `git pull` from upstream risks silently wiping a fork-only change (which has now happened twice — see `0004-fix-discord-restore-response_prefix-interpolation-af.md` for history).

## File format

Each patch is two siblings:

```
patches/
├── NNNN-<slug>.patch    ← git format-patch output, machine-replayable
└── NNNN-<slug>.md       ← human/LLM-readable intent description
```

The `.patch` file is generated with `git format-patch -1 <sha>` and replayable via `git am --3way`. The `.md` file documents:
- **Intent** — what the patch does, and why
- **Where it goes** — file paths and integration points
- **Skip when** — conditions under which the patch should be dropped (e.g. upstream accepted it)
- **Smoke test** — how to verify it works after re-applying
- **Status** — `fork-only`, `upstream-pending`, or `upstream-merged`
- **Last verified** — date + upstream commit SHA at which the patch was confirmed to apply
- **Original commit** — the SHA the `.patch` was generated from

## Replay workflow

After every `git fetch origin && git merge origin/main`:

```bash
./scripts/apply-local-patches.sh
```

The script tries `git am --3way` for each patch in numeric order. On success, the patch is replayed as a new commit on top of upstream. On failure, the script halts and prints the `.md` filename to consult.

## When `git am` fails

This happens when upstream refactors the code the patch targets — function renamed, file moved, surrounding context changed. The line-based diff no longer matches.

**Recovery:** ping Hermes in Discord with the failing patch number. Hermes will:
1. Read the `.md` intent description.
2. Search the current code for where the change should now live.
3. Re-implement the change with Edit/Write, guided by the `.md` spec.
4. Commit the result.
5. Regenerate the `.patch` file from the new commit so next time the patch reflects the current file paths.

This is also the trigger for updating the `Last verified` line in the `.md` to the new upstream commit SHA.

## Current patches

| # | Title | Status |
|---|---|---|
| 0001 | discord: edit_message truncation + mention resolution | fork-only |
| 0002 | kanban: child tasks inherit parent workspace | fork-only |
| 0003 | kanban: ACP subprocess spawning for workers | fork-only |
| 0004 | discord: restore response_prefix interpolation | fork-only |

## Adding a new patch

When you commit a new local-only change to `main`:

```bash
# Assuming the new commit is HEAD
NEXT=$(printf '%04d' $(($(ls patches/*.patch | wc -l) + 1)))
git format-patch -1 HEAD -o patches/ --start-number $NEXT
# Then write patches/NNNN-<slug>.md by hand using existing .md files as a template
```

## Why not just keep the fork's git history as the source of truth?

Because the next `git pull` from upstream can fast-forward (or merge) over local commits that didn't make it back to the fork's `main`. The `patches/` dir is a durable, file-system-level record that's immune to git's history rewrites and remote out-of-sync states. The `.md` sibling is the part that survives if even the patch file itself fails to apply.

## Original-commit-vs-replay-commit drift

After a successful replay on top of upstream, the new commit has a different SHA than the `Original commit` in the `.md`. That's expected. The original commit was on the previous upstream base; the replay is on the new one. The `.patch` file's authorship and message survive — only the SHA changes. We don't try to chase this; the `Original commit` field is historical reference, not a current SHA.
