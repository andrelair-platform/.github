#!/usr/bin/env bash
# bmad-sync-runner.sh — driver invoked by the reusable bmad-sync workflow.
#
# Runs inside the CALLER repo's checkout. Finds every sprint directory under
# <STORIES_ROOT>/.../ that holds at least one story .md, and runs the org-shared bridge over
# each. The bridge is idempotent (skips issues whose [<id>] title already exists), so processing
# every dir on each run is safe and avoids fragile git-diff detection — a re-run only creates
# genuinely-new stories.
#
# Env:
#   BRIDGE       path to bmad-to-github.sh (default: alongside this script)
#   STORIES_ROOT root to scan (default: bmad/stories)
#   GH_TOKEN     gh auth token (required for a real run)
#   DRY_RUN      "true" → pass --dry-run

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BRIDGE="${BRIDGE:-$SCRIPT_DIR/bmad-to-github.sh}"
STORIES_ROOT="${STORIES_ROOT:-bmad/stories}"
DRY_FLAG=""
[ "${DRY_RUN:-false}" = "true" ] && DRY_FLAG="--dry-run"

if [ ! -d "$STORIES_ROOT" ]; then
  echo "No $STORIES_ROOT directory — nothing to sync."
  exit 0
fi

# Sprint dirs = any dir under STORIES_ROOT containing a story .md (excluding the non-story
# manifests). Portable (no mapfile): collect unique dirs via find + sort -u.
sprint_dirs=$(
  find "$STORIES_ROOT" -type f -name '*.md' \
    ! -name 'SPRINT-OVERVIEW.md' ! -name 'IMPL-NOTES.md' ! -name 'README.md' \
    -exec dirname {} \; | sort -u
)

if [ -z "$sprint_dirs" ]; then
  echo "No story files under $STORIES_ROOT — nothing to sync."
  exit 0
fi

echo "Sprint directories to sync:"
echo "$sprint_dirs" | sed 's/^/  - /'
echo ""

rc=0
while IFS= read -r dir; do
  [ -z "$dir" ] && continue
  echo "===> Syncing: $dir"
  # repo / project / milestone all come from each story's frontmatter (per-product model).
  bash "$BRIDGE" "$dir" $DRY_FLAG || rc=$?
  echo ""
done <<EOF
$sprint_dirs
EOF

exit $rc
