# 0006 — feat(discord): source response_prefix name from config instead of hardcoded "Hermes"

## Intent
`discord.response_prefix` (see patch [[0004]]) renders `{name}` in the reply prefix (e.g. `[Hermes · claude-sonnet-5]`), but `{name}` was always the literal string `"Hermes"` — no config field fed it, and `DiscordAdapter.update_response_prefix_context(name=...)` existed but was never called with `name=`. Result: profiles other than the default (e.g. Niro, running the same shared codebase under `--profile niro`) always showed "Hermes" in their own Discord replies, with no way to override via config.

## Where it goes
Two files, one line each:

1. `gateway/config.py` — in `load_gateway_config()`'s `bridged` dict construction (same spot as `response_prefix` itself, ~line 1547). Add a one-liner copying `response_prefix_name` from the platform config into `bridged`, so it flows into `DiscordAdapter.config.extra` via `extra.update(bridged)`.

2. `plugins/platforms/discord/adapter.py` — in `DiscordAdapter.__init__`, where `self._response_prefix_context` is seeded (~line 1070). Change the hardcoded `"name": "Hermes"` to `"name": self.config.extra.get("response_prefix_name") or "Hermes"`.

No change needed in `gateway/run.py` — `name` doesn't change per-reply like `model_full` does, so seeding it once at adapter init from config is sufficient; the existing (unused) `name=` kwarg on `update_response_prefix_context` is left as-is for future per-reply overrides if ever needed.

## Config
```yaml
discord:
  response_prefix: "[{name} · {model}]"
  response_prefix_name: "Niro"
```
Missing key → falls back to `"Hermes"` (unchanged default behavior). Backward compatible — profiles that don't set this key are unaffected.

## Skip when
Upstream adds a native agent-display-name concept that already threads into the Discord prefix. Grep upstream for `response_prefix_name`; if found, drop this patch.

## Smoke test
1. Add `response_prefix_name: 'Niro'` under `discord:` in the profile's `config.yaml` (done for `profiles/niro/config.yaml`).
2. Restart that profile's gateway: `systemctl --user restart hermes-gateway-niro`.
3. Send a message in Discord that triggers a reply from that profile.
4. Reply should start with `[Niro · <model>]` instead of `[Hermes · <model>]`.
5. Confirm the *other* gateway (`hermes-gateway.service`, no `response_prefix_name` set) still shows `[Hermes · <model>]` unaffected — restart it separately to pick up the shared code change, then verify.

## Status
fork-only — same local-only category as [[0004]], no upstream PR.

## Last verified
2026-08-04 — new patch, applied cleanly (no upstream sync involved yet).

## Original commit
`446a46f909` — `feat(discord): source response_prefix name from config instead of hardcoded "Hermes"`
