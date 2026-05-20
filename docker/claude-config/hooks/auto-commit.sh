#!/usr/bin/env bash
# Stop hook — auto-commit any working-tree changes left behind after a turn.
# Ported from nix-zeneca-model; video-domain-agnostic.
#
# Contract:
#   - Run on every agent Stop.
#   - Stage every working-tree change with `git add -A`. Decisions about
#     WHAT gets committed are delegated to `.gitignore`.
#   - Compose a short summary message:
#       * If one or more `docs/issues/*.md` flipped to `status: Review`,
#         `status: Closed`, or `stage: delivered`, summarise as
#         "<ids> auto-commit: …".
#       * Otherwise fall back to "auto: <conventional-tag> tracked edits".
#   - Never push, never amend, never `--no-verify`.
#   - Never abort the Stop event — exit 0 even on transient git failures.

set -eo pipefail

cat >/dev/null

cd "${CLAUDE_PROJECT_DIR:-$(pwd)}" || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

git add -A 2>/dev/null || true

if git diff --quiet --cached 2>/dev/null; then
  exit 0
fi

# Detect issue file state transitions for a richer commit subject.
changed_issue_ids=()
while IFS= read -r path; do
  case "$path" in
    docs/issues/*.md) : ;;
    *) continue ;;
  esac
  [[ ! -f "$path" ]] && continue
  id=$(head -3 "$path" 2>/dev/null | awk -F': ' '/^id:/ { print $2; exit }')
  [[ -z "$id" ]] && continue
  status=$(awk -F': ' '/^status:/ { print $2; exit }' "$path" 2>/dev/null)
  stage=$(awk -F': ' '/^stage:/ { print $2; exit }' "$path" 2>/dev/null)
  if [[ "$status" == "Review" || "$status" == "Closed" || "$stage" == "delivered" ]]; then
    changed_issue_ids+=("$id")
  fi
done < <(git diff --cached --name-only -- 'docs/issues/*.md' 2>/dev/null)

if [[ ${#changed_issue_ids[@]} -gt 0 ]]; then
  ids_joined=$(printf '%s ' "${changed_issue_ids[@]}" | sed 's/ $//')
  subject="${ids_joined} auto-commit: in-progress edits between turns"
else
  diff_paths=$(git diff --cached --name-only 2>/dev/null)
  tag="chore"
  if grep -qE '^(edit|raw|animations)/' <<<"$diff_paths"; then tag="auto"; fi
  if grep -qE '^docs/' <<<"$diff_paths"; then tag="docs"; fi
  if grep -qE '^\.claude/' <<<"$diff_paths"; then tag="config"; fi
  if grep -qE '\.(mp4|mov|mkv|wav|mp3|srt)$' <<<"$diff_paths"; then tag="media"; fi
  subject="auto: ${tag} tracked edits at Stop"
fi

file_count=$(git diff --cached --name-only | wc -l | tr -d ' ')
branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "HEAD")

git commit -m "$(cat <<EOF
${subject}

Auto-committed by .claude/hooks/auto-commit.sh on Stop.
Branch: ${branch}.
Files staged: ${file_count}.
EOF
)" >/dev/null 2>&1 || true

exit 0
