#!/usr/bin/env bash
# Kanban claude-coder wrapper (fork support file, see patches/0008 write-up).
# Installed as ~/.hermes/profiles/claude-coder/bin/claude (symlink to this file).
# The dispatcher strips launch-profile env keys (incl. CLAUDE_CODE_OAUTH_TOKEN)
# from routed-profile workers, so load the long-lived token from the profile's
# own .env here, then exec the real CLI. Named "claude" so the dispatcher's
# basename gate still injects -p, CLAUDE_CONFIG_DIR and the per-task --model.
set -u
ENV_FILE="${CLAUDE_CODER_ENV_FILE:-$HOME/.hermes/profiles/claude-coder/.env}"
tok=$(grep -m1 '^CLAUDE_CODE_OAUTH_TOKEN=' "$ENV_FILE" 2>/dev/null | cut -d= -f2- | sed -e 's/^["'"'"']//' -e 's/["'"'"']$//')
[ -n "$tok" ] && export CLAUDE_CODE_OAUTH_TOKEN="$tok"

# Locate the real CLI without hardcoding a Node version:
# 1. $CLAUDE_REAL_BIN override  2. newest nvm Node that has claude
# 3. first non-wrapper `claude` on PATH
real="${CLAUDE_REAL_BIN:-}"
if [ -z "$real" ]; then
  for c in $(ls -d "$HOME"/.nvm/versions/node/*/bin/claude 2>/dev/null | sort -V -r); do
    [ -x "$c" ] && { real="$c"; break; }
  done
fi
if [ -z "$real" ]; then
  self=$(readlink -f "$0")
  IFS=: read -ra dirs <<< "$PATH"
  for d in "${dirs[@]}"; do
    c="$d/claude"
    [ -x "$c" ] && [ "$(readlink -f "$c")" != "$self" ] && { real="$c"; break; }
  done
fi
[ -x "${real:-}" ] || { echo "claude-coder wrapper: real claude CLI not found" >&2; exit 127; }
exec "$real" "$@"
