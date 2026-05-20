---
description: Show the active FSH project's manifest, stage, and open issues.
argument-hint: [project-name]
---

# /fsh-status — print project state

If `$1` is given, report on `/work/$1/`. Otherwise auto-detect the
most-recently-modified non-delivered project under `/work/`.

## What to do

1. **Resolve project id.** If `$1` given, use it. Otherwise:
   ```bash
   ls -td /work/*/ 2>/dev/null \
     | while read d; do
         id=$(basename "$d")
         [ "$id" = ".queue" ] && continue
         stage=$(jq -r '.stage // "unknown"' "$d/manifest.json" 2>/dev/null)
         [ "$stage" = "delivered" ] && continue
         echo "$id"
         break
       done
   ```

2. **Print a tight summary**, formatted like:
   ```
   project:      <id>
   stage:        <stage>
   prompt:       <prompt summary>
   inputs:       <N> source(s), total <duration>
   strategy:     <approved | pending | rejected>
   edl:          <ranges count> ranges, <total_duration_s>s
   overlays:     <N planned> / <N rendered>
   render:       <preview present? final present?>
   self-eval:    <PASS | FAIL | not run>
   delivery:     <files in /assets/<id>/output/>
   open issues:  <count> (P0:<n> P1:<n> P2:<n>)
   ```

3. **List open issues** (one-line each):
   ```bash
   for f in /work/$id/docs/issues/*.md; do
       [ -f "$f" ] || continue
       grep -qE '^status: (Open|Active|Review)' "$f" || continue
       awk -F': ' '
           /^id:/ {id=$2}
           /^title:/ {title=$2}
           /^priority:/ {pri=$2}
           /^status:/ {st=$2}
           END {printf "  %s [%s/%s] %s\n", id, pri, st, title}
       ' "$f"
   done
   ```

4. **Next action** (call `loop-not-done.sh` in dry-run mode):
   ```bash
   bash /opt/claude-config/hooks/loop-not-done.sh </dev/null 2>&1 \
     | head -1
   ```

5. **Output to user.** Do NOT modify any state.
