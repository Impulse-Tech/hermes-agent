# 0004 — fix(discord): restore response_prefix interpolation after plugin refactor

## Intent
Restore Discord's per-reply prefix rendering (e.g. `[Hermes · claude-opus-4-7]`) using the `discord.response_prefix` template from config.yaml. Upstream's 2026-05-31 refactor moved `gateway/platforms/discord.py` → `plugins/platforms/discord/adapter.py` and dropped the prefix mechanism entirely. The config key was left intact but read by nothing.

This is the SECOND time this regression has occurred (first in April 2026, also patched then). The patch-tracking system this directory lives in exists specifically to prevent a third occurrence.

## Where it goes
Three files coordinate to make the prefix work:

1. `gateway/config.py` — in `load_gateway_config()`, the `bridged` dict construction. Add a one-liner that copies `response_prefix` from the platform config into the adapter's `extra` dict (currently does this for `reply_prefix`, `reply_in_thread`, `require_mention`).

2. `plugins/platforms/discord/adapter.py` — three additions:
   - Module-level helpers: `_extract_model_parts(model_full)` (splits `provider/short` form) + `interpolate_response_prefix(template, name, model_full)` (renders the template).
   - On `DiscordAdapter.__init__`: initialize `self._response_prefix_context = {"name": "Hermes", "model_full": <env or config default>}`.
   - New method `DiscordAdapter.update_response_prefix_context(*, name=None, model_full=None)` for the gateway to push live model info.
   - In the adapter's `send()` method (the outbound message handler): if `self.config.extra.get("response_prefix")` is set, call `interpolate_response_prefix(...)` with the context and prepend to outgoing `content`.

3. `gateway/run.py` — in `GatewayRunner` post-agent-run hook (search for `agent_result.get("model")` or similar near the response-dispatch logic). Add a block that, when `source.platform == Platform.DISCORD`, calls `_prefix_adapter.update_response_prefix_context(model_full=<resolved model>)`. This must run BEFORE `adapter.send()` so the prefix reflects the actual model used (matters when there's a fallback).

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
2026-08-01 against upstream commit `470cf66b039c73bdd2c21d43094ce41a4db74eae` — required manual conflict resolution: upstream inserted several new `__init__` attributes (`_nonconversational_messages`, `_last_overflow_preview`, `_warned_fail_closed_default`) and three new helper methods (`_config_value`, `_finite_positive_config_float`, `_config_int`) between the patch's anchor line and `connect()`, which made the 3-way merge conflict-mark a wide span it couldn't confidently splice. Resolved by keeping all of upstream's additions and appending `_response_prefix_context` init + `update_response_prefix_context` at the true end of `__init__`. `gateway/config.py`, `gateway/run.py`, and the `interpolate_response_prefix`/`_extract_model_parts` helpers + `send()` prefix-injection in `adapter.py` all applied with zero conflicts.

## History
- 2026-04-XX — first regression on a prior upstream sync; restored by cherry-pick (no tracking, lost on next sync).
- 2026-05-31 — second regression on upstream sync that moved `discord.py` → `discord/adapter.py` plugin.
- 2026-06-07 — restored via this patch; tracked in `patches/` going forward.
- 2026-08-01 — third upstream sync; patch required manual `__init__` conflict resolution (see above) but did NOT regress — tracking system worked as intended.

## Original commit
`24d84b43a` — `fix(discord): restore response_prefix interpolation after plugin refactor`
