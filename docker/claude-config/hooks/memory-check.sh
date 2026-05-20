#!/usr/bin/env bash
# memory-check.sh — Stop-hook addition that detects "findings worth saving"
# and emits a directive to write them when the memory dir is empty.
#
# Smoke #1 wrote memories spontaneously. Smoke #2 + #3 wrote ZERO despite
# the same agents/CLAUDE.md doctrine. The CLAUDE.md text isn't driving
# behavior on long runs. This hook makes the doctrine ENFORCED instead
# of advisory.
#
# Trigger logic: if the active project has captured real findings AND
# the memory dir is empty, emit a directive listing the specific
# findings the agent should save. Don't block — the auto-commit hook
# above us still runs — but inject a directive that becomes the
# next-action.
#
# Findings considered save-worthy:
# - manifest.audience_persona set + non-default
# - manifest.brand.name set (with brand voice / colors)
# - manifest.inputs[].quirks[] with `confirmed_by: visual-comparison`
# - dropin-scaffold-blocked or fetch-blocked entries in docs/issues/
# - newly authored tools in /agents/fsh-tools/
# - newly added entries in /agents/system-packages.txt or python-packages.txt
#
# Output: directive on stderr (exit 0 = no directive; exit 2 = directive emitted).

set -u

WORK_ROOT="${FSH_WORK_ROOT:-/work}"
MEM_DIR="/root/.claude/projects/-work/memory"

# Find the active project (most-recently-modified non-delivered)
active=""
newest_mtime=0
shopt -s nullglob
for d in "$WORK_ROOT"/*/; do
  [ -d "$d" ] || continue
  id=$(basename "$d")
  [ "$id" = ".queue" ] && continue
  if [ -f "$d/manifest.json" ]; then
    stage=$(jq -r '.stage // "input-received"' "$d/manifest.json" 2>/dev/null)
    [ "$stage" = "delivered" ] && continue
  fi
  mtime=$(stat -c %Y "$d" 2>/dev/null || echo 0)
  if [ "$mtime" -gt "$newest_mtime" ]; then
    newest_mtime=$mtime
    active="$id"
  fi
done
shopt -u nullglob

# No active project? Nothing to nag about.
[ -z "$active" ] && exit 0

M="$WORK_ROOT/$active/manifest.json"
[ -f "$M" ] || exit 0

# Collect findings — only "real" ones (not the scaffold defaults)
findings=()

persona=$(jq -r '.audience_persona // empty' "$M" 2>/dev/null)
if [ -n "$persona" ] && [ "$persona" != "null" ]; then
  findings+=("audience_persona=$persona")
fi

brand_name=$(jq -r '.brand.name // empty' "$M" 2>/dev/null)
if [ -n "$brand_name" ] && [ "$brand_name" != "null" ]; then
  findings+=("brand=$brand_name")
fi

quirks_count=$(jq -r '[.inputs[]?.quirks[]? | select(.confirmed_by == "visual-comparison")] | length' "$M" 2>/dev/null)
[ "${quirks_count:-0}" -gt 0 ] && findings+=("camera_quirks=$quirks_count_confirmed")

# Authored tools / hooks since project start
authored_tools=$(find /agents/fsh-tools -maxdepth 1 -type f -not -name ".gitkeep" 2>/dev/null | wc -l)
authored_hooks=$(find /agents/fsh-hooks -maxdepth 1 -type f -not -name ".gitkeep" 2>/dev/null | wc -l)
[ "${authored_tools:-0}" -gt 0 ] && findings+=("authored_tools=$authored_tools")
[ "${authored_hooks:-0}" -gt 0 ] && findings+=("authored_hooks=$authored_hooks")

# Blocked-fetch issues (real failures worth remembering)
blocked_issues=$(find "$WORK_ROOT/$active/docs/issues" -maxdepth 1 -name "*blocked*" -o -name "*denied*" -o -name "*pending*" 2>/dev/null | wc -l)
[ "${blocked_issues:-0}" -gt 0 ] && findings+=("blocked_issues=$blocked_issues")

# Nothing memorable? Don't nag.
[ "${#findings[@]}" -eq 0 ] && exit 0

# Memory dir has content? Done.
if [ -d "$MEM_DIR" ]; then
  count=$(find "$MEM_DIR" -maxdepth 1 -name "*.md" -not -name "MEMORY.md" 2>/dev/null | wc -l)
  [ "${count:-0}" -gt 0 ] && exit 0
fi

# Findings exist + memory dir is empty → emit directive
printf 'Good. Now focus on this: you have captured real project findings (%s) but written zero entries to /root/.claude/projects/-work/memory/. Per /agents/CLAUDE.md § "Persistent memory — use it", write memory files NOW for each: project memory for "%s" with the brand voice, audience persona, and any peer-brand observations; reference memories for any blocked-fetch failure modes you hit; feedback memories for anything the user-directed work taught you about how to operate. Use the format documented in /agents/CLAUDE.md. Index in MEMORY.md. Then continue.\n' \
  "${findings[*]}" \
  "$active" >&2

exit 2
