#!/usr/bin/env bash
# Replay all patches in patches/*.patch in numeric order onto the current branch.
#
# Run after every upstream sync (git fetch origin && git merge origin/main).
# Halts on the first patch that fails to apply, and prints the .md sibling
# to consult for re-applying by hand (or via Hermes).
#
# Usage: ./scripts/apply-local-patches.sh
#
# Exit codes:
#   0 — all patches applied cleanly (or no patches present)
#   1 — a patch failed to apply; manual intervention needed
#   2 — environment/repo problem (not in a git repo, dirty tree, etc.)

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    echo "ERROR: not inside a git repository" >&2
    exit 2
}

cd "$REPO_ROOT"

PATCH_DIR="$REPO_ROOT/patches"
if [ ! -d "$PATCH_DIR" ]; then
    echo "No patches/ directory found at $PATCH_DIR — nothing to apply."
    exit 0
fi

# Refuse to run on a dirty working tree — git am will fail confusingly.
if ! git diff-index --quiet HEAD --; then
    echo "ERROR: working tree has uncommitted changes. Commit or stash first." >&2
    exit 2
fi

PATCHES=()
while IFS= read -r p; do
    PATCHES+=("$p")
done < <(find "$PATCH_DIR" -maxdepth 1 -name '*.patch' -type f | sort)

if [ "${#PATCHES[@]}" -eq 0 ]; then
    echo "No .patch files in $PATCH_DIR — nothing to apply."
    exit 0
fi

echo "Applying ${#PATCHES[@]} patch(es) in order..."
echo ""

for p in "${PATCHES[@]}"; do
    base="${p%.patch}"
    name="$(basename "$p")"
    md="${base}.md"

    echo "==> $name"

    if git am --3way --quiet "$p"; then
        echo "    OK"
    else
        echo ""
        echo "    FAILED: git am could not apply $name cleanly."
        git am --abort 2>/dev/null || true
        echo ""
        echo "    Next steps:"
        if [ -f "$md" ]; then
            echo "      1. Read the intent description:"
            echo "         cat $md"
        else
            echo "      1. No .md sibling found at $md — patch lacks an intent doc."
        fi
        echo "      2. Either re-implement the change by hand,"
        echo "         or ping Hermes in Discord: '@Hermes re-apply patch $(basename "$base")'"
        echo "      3. Once re-applied as a new commit, regenerate the patch file:"
        echo "         git format-patch -1 HEAD -o patches/ --start-number <N>"
        echo "         mv patches/<new-file> $name   # keep the slot number"
        echo "      4. Update '$md' Last-verified line with the new upstream SHA."
        echo ""
        exit 1
    fi
done

echo ""
echo "All patches applied successfully."
