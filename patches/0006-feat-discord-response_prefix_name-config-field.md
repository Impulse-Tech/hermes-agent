# 0006 — feat(discord): source response_prefix name from config instead of hardcoded "Hermes"

## Intent
`discord.response_prefix` (see patch [[0004]]) renders `{name}` in the reply prefix (e.g. `[Hermes · claude-sonnet-5]`), but `{name}` was always the literal string `"Hermes"` — no config field fed it, and `DiscordAdapter.update_response_prefix_context(name=...)` existed but was never called with `name=`. Result: profiles other than the default (e.g. Niro, running the same shared codebase under `--profile niro`) always showed "Hermes" in their own Discord replies, with no way to override via config.

## Where it goes
**As of 2026-10-13, only one file needs touching** — same reason as [[0004]]'s config-bridging drop.

1. ~~`gateway/config.py` bridging~~ — **no longer needed**, `response_prefix_name` is just as un-typed as `response_prefix` and rides the same generic `PlatformConfig.from_dict` passthrough (see [[0004]]).

2. `plugins/platforms/discord/adapter.py` — in `DiscordAdapter.__init__`, where `self._response_prefix_context` is seeded (now inside the block [[0004]] added, right after `self._warned_fail_closed_default = False`). Change the hardcoded `"name": "Hermes"` to `"name": self.config.extra.get("response_prefix_name") or "Hermes"`.

No change needed in `gateway/run.py`/`gateway/run_turn.py` — `name` doesn't change per-reply like `model_full` does, so seeding it once at adapter init from config is sufficient; the existing (unused) `name=` kwarg on `update_response_prefix_context` is left as-is for future per-reply overrides if ever needed.

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
2026-10-13 against upstream commit `9e041a7428392b01b989ef9cecf46a5f96be12fc` — `git am` failed (depends on [[0004]]'s `__init__` block which itself moved); hand-ported as a one-line change onto the hand-ported 0004 block.

## Original commit
`446a46f909` — `feat(discord): source response_prefix name from config instead of hardcoded "Hermes"` (hand-ported again as `51cdd216fd` on 2026-10-13)
