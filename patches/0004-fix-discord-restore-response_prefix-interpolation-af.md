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
2026-06-07 against upstream commit `1fc7bdc5e64e052bc61d3ddb9e6f96cf6c7461dc`

## History
- 2026-04-XX — first regression on a prior upstream sync; restored by cherry-pick (no tracking, lost on next sync).
- 2026-05-31 — second regression on upstream sync that moved `discord.py` → `discord/adapter.py` plugin.
- 2026-06-07 — restored via this patch; tracked in `patches/` going forward.

## Original commit
`24d84b43a` — `fix(discord): restore response_prefix interpolation after plugin refactor`
