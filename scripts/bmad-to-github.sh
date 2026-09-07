#!/usr/bin/env bash
# bmad-to-github.sh — push BMAD story files to GitHub Issues (org-shared bridge)
#
# This is the SINGLE, org-wide bridge, hosted in andrelair-platform/.github and consumed
# by every repo via the reusable workflow (.github/workflows/bmad-sync.yml, workflow_call).
# Per-repo BMAD: each repo owns its own bmad/stories/ + a ~15-line caller workflow; the
# bridge logic lives here once so it never drifts across repos.
#
# Usage:
#   ./bmad-to-github.sh <story-dir> [options]
#
# Options:
#   --repo <org/repo>       DEFAULT target repo (fallback if a story omits `repo:`)
#   --project <number>      DEFAULT GitHub Project number (fallback if a story omits `project:`)
#   --milestone <title>     DEFAULT milestone (fallback if a story omits `milestone:`)
#   --dry-run               print what would happen, create nothing
#
# Per-story frontmatter wins over the CLI defaults (2-tier routing): `repo:`, `project:`
# and `milestone:` may each be set per story so a service's work lands in its own repo /
# board / milestone. A repo running its own sync typically sets these in frontmatter and
# passes no CLI overrides at all.
#
# Idempotent: issues already containing [<id>] in their title are skipped.
# Requirements: gh CLI authenticated (GH_TOKEN), python3 in PATH.

set -euo pipefail

STORY_DIR=""
REPO="${DEFAULT_REPO:-}"
PROJECT_NUMBER="${DEFAULT_PROJECT:-}"
MILESTONE_TITLE=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --repo)      REPO="$2";             shift 2 ;;
    --project)   PROJECT_NUMBER="$2";   shift 2 ;;
    --milestone) MILESTONE_TITLE="$2";  shift 2 ;;
    --dry-run)   DRY_RUN=true;          shift   ;;
    *)           STORY_DIR="$1";        shift   ;;
  esac
done

if [[ -z "$STORY_DIR" ]]; then
  echo "Error: story directory required" >&2
  echo "Usage: $0 <story-dir> [--repo org/repo] [--project N] [--milestone 'title'] [--dry-run]" >&2
  exit 1
fi
if [[ ! -d "$STORY_DIR" ]]; then
  echo "Error: directory not found: $STORY_DIR" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Parse YAML frontmatter from a story file
# ---------------------------------------------------------------------------
parse_frontmatter() {
  local file="$1"
  python3 - "$file" <<'PYEOF'
import sys, re

with open(sys.argv[1]) as f:
    content = f.read()

m = re.match(r'^---\n(.*?)\n---\n', content, re.DOTALL)
if not m:
    sys.exit(1)

yaml_block = m.group(1)
body = content[m.end():]

def parse_yaml(text):
    result = {}
    lines = text.split('\n')
    i = 0
    while i < len(lines):
        line = lines[i]
        if not line.strip() or line.strip().startswith('#'):
            i += 1
            continue
        km = re.match(r'^(\w[\w/]*)\s*:\s*(.*)', line)
        if km:
            key, val = km.group(1), km.group(2).strip()
            if val.startswith('['):
                items = re.findall(r'[\w\-/.: ]+', val[1:val.rfind(']')])
                result[key] = [x.strip() for x in items if x.strip()]
            elif val.startswith('"') or val.startswith("'"):
                result[key] = val.strip('"\'')
            elif val == '':
                sub_items = []
                i += 1
                while i < len(lines) and lines[i].startswith('  - '):
                    sub_items.append(lines[i].strip()[2:])
                    i += 1
                result[key] = sub_items
                continue
            else:
                result[key] = val
        i += 1
    return result

meta = parse_yaml(yaml_block)

story_id = meta.get('id', '')
if not story_id:
    # No id → not a real story (e.g. SPRINT-OVERVIEW, IMPL-NOTES) → skip.
    sys.exit(1)

raw_title = meta.get('title', '')
prefixed_title = f"[{story_id}] {raw_title}" if story_id else raw_title

labels = meta.get('labels', [])
labels_str = ','.join(labels) if isinstance(labels, list) else str(labels)

print(f"TITLE={prefixed_title}")
print(f"ESTIMATE={meta.get('estimate', '')}")
print(f"LABELS={labels_str}")
print(f"STORY_ID={story_id}")
print(f"REPO_OVERRIDE={meta.get('repo', '')}")
print(f"PROJECT_OVERRIDE={meta.get('project', '')}")
print(f"MILESTONE_OVERRIDE={meta.get('milestone', '')}")
print("---BODY---")
print(body.strip())
PYEOF
}

# ---------------------------------------------------------------------------
# Auto-create missing labels on the routed repo
# ---------------------------------------------------------------------------
ensure_labels() {
  local labels_csv="$1" target_repo="$2"
  IFS=',' read -ra arr <<< "$labels_csv"
  for label in "${arr[@]}"; do
    label=$(echo "$label" | xargs)
    [[ -z "$label" ]] && continue
    gh label create "$label" --color "6b7280" --description "BMAD label" \
      --repo "$target_repo" 2>/dev/null || true
  done
}

# ---------------------------------------------------------------------------
# Verify a milestone exists on a repo. Echoes the title if found, else empty.
# (No associative-array cache — kept portable to bash 3.2; a sprint is a handful
# of stories so a query per story is negligible.)
# ---------------------------------------------------------------------------
verify_milestone() {
  local title="$1" target_repo="$2" n
  [[ -z "$title" ]] && { echo ""; return; }
  n=$(gh api "repos/${target_repo}/milestones" \
        --jq ".[] | select(.title == \"$title\") | .number" 2>/dev/null | head -1)
  [[ -n "$n" ]] && echo "$title" || echo ""
}

# ---------------------------------------------------------------------------
echo "==> Scanning: $STORY_DIR"
[[ -n "$REPO" ]]            && echo "==> Default repo:     $REPO"
[[ -n "$PROJECT_NUMBER" ]] && echo "==> Default project:  #$PROJECT_NUMBER"
[[ "$DRY_RUN" == true ]]   && echo "==> DRY RUN — no issues will be created"
echo ""

created=0
skipped=0

# Glob ALL markdown (not just S*.md) so RTV-##-*.md and other id schemes work; files
# without frontmatter/id (SPRINT-OVERVIEW, IMPL-NOTES, README) are skipped by the parser.
shopt -s nullglob
for story_file in "$STORY_DIR"/*.md; do
  base=$(basename "$story_file")
  case "$base" in SPRINT-OVERVIEW.md|IMPL-NOTES.md|README.md) continue ;; esac

  parsed=$(parse_frontmatter "$story_file") || continue   # no frontmatter/id → not a story

  TITLE=$(echo    "$parsed" | grep '^TITLE='    | cut -d= -f2-)
  LABELS=$(echo   "$parsed" | grep '^LABELS='   | cut -d= -f2-)
  STORY_ID=$(echo "$parsed" | grep '^STORY_ID=' | cut -d= -f2-)
  ESTIMATE=$(echo "$parsed" | grep '^ESTIMATE=' | cut -d= -f2-)
  REPO_OVERRIDE=$(echo      "$parsed" | grep '^REPO_OVERRIDE='      | cut -d= -f2-)
  PROJECT_OVERRIDE=$(echo   "$parsed" | grep '^PROJECT_OVERRIDE='   | cut -d= -f2-)
  MILESTONE_OVERRIDE=$(echo "$parsed" | grep '^MILESTONE_OVERRIDE=' | cut -d= -f2-)
  BODY=$(echo     "$parsed" | awk '/^---BODY---/{found=1; next} found{print}')

  ISSUE_REPO="${REPO_OVERRIDE:-$REPO}"
  ISSUE_PROJECT="${PROJECT_OVERRIDE:-$PROJECT_NUMBER}"
  ISSUE_MILESTONE="${MILESTONE_OVERRIDE:-$MILESTONE_TITLE}"

  if [[ -z "$ISSUE_REPO" ]]; then
    echo "  [SKIP] $base — no repo (set frontmatter repo: or pass --repo)"
    skipped=$((skipped + 1)); continue
  fi

  BODY="${BODY}

---
**Estimate:** ${ESTIMATE} story points | **BMAD ID:** \`${STORY_ID}\`"

  echo "  [STORY] $STORY_ID → $ISSUE_REPO (project #${ISSUE_PROJECT:-none})"
  echo "          Title:  $TITLE"

  if [[ "$DRY_RUN" == true ]]; then
    echo "          [DRY RUN] Would create issue"
    created=$((created + 1)); continue
  fi

  existing=$(gh issue list --repo "$ISSUE_REPO" --search "[${STORY_ID}] in:title" \
              --json number --jq '.[0].number' 2>/dev/null || true)
  if [[ -n "$existing" ]]; then
    echo "          [SKIP] Already exists as #$existing"
    skipped=$((skipped + 1)); continue
  fi

  ensure_labels "$LABELS" "$ISSUE_REPO"

  gh_args=(issue create --repo "$ISSUE_REPO" --title "$TITLE" --body "$BODY")
  IFS=',' read -ra label_arr <<< "$LABELS"
  for label in "${label_arr[@]}"; do
    label=$(echo "$label" | xargs)
    [[ -n "$label" ]] && gh_args+=(--label "$label")
  done

  ms_ok=$(verify_milestone "$ISSUE_MILESTONE" "$ISSUE_REPO")
  if [[ -n "$ISSUE_MILESTONE" && -z "$ms_ok" ]]; then
    echo "          Warning: milestone '$ISSUE_MILESTONE' not on $ISSUE_REPO — creating without it" >&2
  fi
  [[ -n "$ms_ok" ]] && gh_args+=(--milestone "$ms_ok")

  issue_url=$(gh "${gh_args[@]}" 2>&1) || {
    echo "          Error: $issue_url" >&2; continue
  }
  echo "          Created: $issue_url"

  if [[ -n "$ISSUE_PROJECT" ]]; then
    gh project item-add "$ISSUE_PROJECT" --owner "$(cut -d/ -f1 <<< "$ISSUE_REPO")" \
      --url "$issue_url" 2>/dev/null \
      && echo "          Added to project #$ISSUE_PROJECT" \
      || echo "          Warning: project add failed (non-fatal)"
  fi

  created=$((created + 1)); sleep 1
done

echo ""
echo "==> Done. Created: $created | Skipped (already exist / not a story): $skipped"
