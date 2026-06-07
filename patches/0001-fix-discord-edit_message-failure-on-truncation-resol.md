# 0001 — fix(discord): edit_message failure on truncation + resolve <@ID> to @DisplayName

## Intent
Two related Discord-adapter fixes bundled in one commit:
1. Discord's `message.edit()` was failing silently when the new content exceeded the channel's character limit. The fix truncates content on edit the same way it already does on send.
2. When the bot receives a message containing a raw mention like `<@1087218272707035218>`, resolve it to `@DisplayName` before passing to the agent so the LLM sees a human-readable name, not a numeric ID.

## Where it goes
- `plugins/platforms/discord/adapter.py` — the truncation fix lives in or near `edit_message()`. The mention-resolution lives in the inbound message handler that turns Discord messages into agent input (`on_message` / handler for incoming events).

## Skip when
- Upstream adds either fix natively. Watch for: any commit that touches `edit_message` truncation, or any handler change that resolves `<@ID>` → display name before agent dispatch.

## Smoke test
1. Send a message in any Discord channel: `@Hermes echo a very long message that exceeds 2000 chars (paste a wall of text)`.
2. Bot should either reply with truncated content OR successfully edit a prior reply without error.
3. Send: `@Hermes who is <@1087218272707035218>?`
4. Bot's recorded input should show `@Yang` (or `@<DisplayName>`), not the numeric ID.

## Status
fork-only (Yang declined upstream PR)

## Last verified
2026-06-07 against upstream commit `1fc7bdc5e64e052bc61d3ddb9e6f96cf6c7461dc` (origin/main HEAD)

## Original commit
`9e341c745` — `fix(discord): edit_message failure on truncation + resolve <@ID> to @DisplayName`
