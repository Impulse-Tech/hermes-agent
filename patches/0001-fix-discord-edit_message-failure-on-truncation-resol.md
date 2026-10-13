# 0001 — fix(discord): resolve <@ID> to @DisplayName before agent dispatch

## Intent
Originally two related Discord-adapter fixes bundled in one commit; now just one (see Status).
1. ~~Discord's `message.edit()` was failing silently when the new content exceeded the channel's character limit.~~ — **dropped, see Status**.
2. When the bot receives a message containing a raw mention like `<@1087218272707035218>`, resolve it to `@DisplayName` before passing to the agent so the LLM sees a human-readable name, not a numeric ID.

## Where it goes
- `plugins/platforms/discord/adapter.py` — the mention-resolution lives in the inbound message handler that turns Discord messages into agent input, right after the bot's own self-mention is stripped from `normalized_content` (search for `_self_is_explicitly_mentioned`).

## Skip when
- Upstream adds mention-resolution natively. Watch for: any handler change that resolves `<@ID>` → display name before agent dispatch.

## Smoke test
1. Send: `@Hermes who is <@1087218272707035218>?`
2. Bot's recorded input should show `@Yang` (or `@<DisplayName>`), not the numeric ID.

## Status
fork-only (Yang declined upstream PR) — **part 1 (edit_message truncation) dropped 2026-08-01**: upstream's `edit_message()` now has a native, more sophisticated fix (`finalize` flag, `_edit_overflow_split`, saturated-preview dedup, reactive split-on-Discord-error) that supersedes the old truncate-with-"..." patch. Only part 2 (mention resolution) still applies.

## Last verified
2026-10-13 against upstream commit `9e041a7428392b01b989ef9cecf46a5f96be12fc` — applied cleanly via `git am --3way`, zero conflicts (31,973-commit sync from the previous 2026-08-01 base).

## Original commit
`9e341c745` — `fix(discord): edit_message failure on truncation + resolve <@ID> to @DisplayName` (superseded by `8a888a9c3c` on the 2026-08-01 upstream-sync branch, part-1-only; replayed again unchanged as `74af46e313` on 2026-10-13)
