# 0004 — fix(discord): restore response_prefix interpolation after plugin refactor

## Intent
Restore Discord's per-reply prefix rendering (e.g. `[Hermes · claude-opus-4-7]`) using the `discord.response_prefix` template from config.yaml. Upstream's 2026-05-31 refactor moved `gateway/platforms/discord.py` → `plugins/platforms/discord/adapter.py` and dropped the prefix mechanism entirely. The config key was left intact but read by nothing.

This is the SECOND time this regression has occurred (first in April 2026, also patched then). The patch-tracking system this directory lives in exists specifically to prevent a third occurrence.

## Where it goes
**As of 2026-10-13, only two files need touching** — the config-bridging file is gone, see note below.

1. ~~`gateway/config.py` bridging~~ — **no longer needed.** Upstream's #10206 refactor made `PlatformConfig.from_dict()` promote every non-typed top-level key in a platform block into `extra` generically (`gateway/config.py` ~line 452: "Promote every non-typed top-level key so neither spelling is silently dropped"). Since `response_prefix` was never added to `PlatformConfig._TYPED_KEYS`, a root-level `discord: response_prefix: ...` block already lands in `self.config.extra["response_prefix"]` with zero fork code. Verified by reading `_bridged_keys()`/`_SHARED_KEYS` in `gateway/config_loader.py` and `PlatformConfig.from_dict` in `gateway/config.py` directly — `response_prefix` was never added to `_TYPED_KEYS`, and the generic passthrough already covers it.

2. `plugins/platforms/discord/adapter.py` — same three additions as before, same relative structure:
   - Module-level helpers `_extract_model_parts()` + `interpolate_response_prefix()`, inserted between `check_discord_requirements()` and `_build_allowed_mentions()`.
   - `DiscordAdapter.__init__`: `self._response_prefix_context` seeded right after `self._warned_fail_closed_default = False`.
   - `update_response_prefix_context()` method, right after `__init__`.
   - `send()`: prefix application inserted after the empty-content guard (`_record_response_async` early-return), before the `try:` block — must run AFTER that guard so an empty agent reply still gets dropped rather than becoming "just the prefix".

3. `gateway/run.py` — **moved to `gateway/run_turn.py`** by the same module-split that hit kanban (see [[0003]]). The anchor is now `GatewayTurnMixin._hmwa_post_turn_hooks(self, hook_ctx, agent_result, response)` — added a `source=None` param, and the model-context push sits right after the existing `hooks.emit("agent:end", ...)` call, before the "Pending process watchers" block. The one caller (`_handle_message_with_agent`) was updated to pass `source` through. Uses `self._delivery_adapter_for(source)` (upstream's current multi-profile/multiplex-aware adapter lookup) instead of the original patch's naive `self.adapters.get(source.platform)`, which didn't exist as a reliable path anymore and wouldn't have handled profile routing correctly.

## Template variables supported
- `{name}` — agent display name (default `Hermes`)
- `{model}` — short model name (last `/`-separated segment, e.g. `claude-opus-4-7`)
- `{modelFull}` — full model with provider prefix (e.g. `openrouter/anthropic/claude-opus-4-7`)
- `{provider}` — provider only (everything before the last `/`)

## Config
```yaml
discord:
  response_prefix: "[{name} · {model}]"
```
Empty string or missing key → no prefix. Backward compatible.

## Skip when
Upstream adds `response_prefix` support natively in the Discord plugin. Grep upstream for `response_prefix` in `plugins/platforms/discord/`; if found, drop this patch.

## Smoke test
1. Restart gateway: `systemctl --user restart hermes-gateway`.
2. Send any message in Discord that triggers an agent reply.
3. Reply should start with `[Hermes · <model>]` matching the configured template.
4. If running through claude-bridge (Max plan), verify the model in the prefix matches what `claude -p` is actually using (NOT what's in `config.yaml` model field — those can differ).

## Status
fork-only — Yang declined upstream PR (this is local-only behavior)

## Last verified
2026-10-13 against upstream commit `9e041a7428392b01b989ef9cecf46a5f96be12fc` — `git am` failed outright this time (not just a conflict — `gateway/run.py`'s anchor function doesn't exist anymore, moved to `gateway/run_turn.py`). Hand-ported; see "Where it goes" above for what changed structurally. Smoke test not yet re-run against a live gateway as of this writing — do that before trusting the prefix shows up for real (see Smoke test section).

## History
- 2026-04-XX — first regression on a prior upstream sync; restored by cherry-pick (no tracking, lost on next sync).
- 2026-05-31 — second regression on upstream sync that moved `discord.py` → `discord/adapter.py` plugin.
- 2026-06-07 — restored via this patch; tracked in `patches/` going forward.
- 2026-08-01 — third upstream sync; patch required manual `__init__` conflict resolution but did NOT regress — tracking system worked as intended.
- 2026-10-13 — fourth upstream sync (31,973 commits); `git am` failed outright (function moved modules, not just conflicted). Hand-ported again; the `gateway/config.py` third of the original patch turned out to be fully obsolete (upstream's generic extra-passthrough already covers it) — one less file to carry forward.

## Original commit
`24d84b43a` — `fix(discord): restore response_prefix interpolation after plugin refactor`
