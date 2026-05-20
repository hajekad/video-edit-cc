#!/usr/bin/env bash
# Video-pipeline gates. Called by the agent (and by loop-not-done.sh in
# verify mode) to check whether a project actually meets the bar for its
# stated stage. Replaces nix-zeneca's `make audit/test-full/conformance`.
#
# Usage:
#   pipeline-gates.sh <project-id> [<stage>]
#     <stage> defaults to current manifest.stage
#
# Exit codes:
#   0  all gates for the stage passed
#   1  one or more gates failed (stderr contains the list)
#   2  invalid usage / missing project

set -eo pipefail

WORK_ROOT="${FSH_WORK_ROOT:-/work}"
ID="${1:?usage: pipeline-gates.sh <project-id> [<stage>]}"
PROJ="$WORK_ROOT/$ID"
[ -d "$PROJ" ] || { echo "no such project: $PROJ" >&2; exit 2; }

MANIFEST="$PROJ/manifest.json"
[ -f "$MANIFEST" ] || { echo "missing manifest.json in $PROJ" >&2; exit 2; }

STAGE="${2:-$(jq -r '.stage // "input-received"' "$MANIFEST")}"

fail=0
fail_with() { printf '%s FAIL: %s\n' "$STAGE" "$1" >&2; fail=$((fail+1)); }

# Gates accumulate downward: each stage requires everything before it.
case "$STAGE" in
  delivered)
    [ -f "$PROJ/edit/final.mp4" ] || fail_with "final.mp4 missing"
    if [ -f "$PROJ/edit/final.mp4" ]; then
      sz=$(stat -c %s "$PROJ/edit/final.mp4" 2>/dev/null || echo 0)
      [ "$sz" -lt 1048576 ] && fail_with "final.mp4 < 1MB ($sz bytes); likely truncated"
    fi
    asset_out="/assets/$ID/output"
    [ -d "$asset_out" ] && [ -f "$asset_out/final.mp4" ] || fail_with "delivery copy missing in $asset_out/final.mp4"
    ;& # fall through

  self-eval-passed)
    [ -f "$PROJ/.claude/state/self-eval.verdict" ] || fail_with "self-eval.verdict missing"
    if [ -f "$PROJ/.claude/state/self-eval.verdict" ]; then
      head -1 "$PROJ/.claude/state/self-eval.verdict" | grep -qE '^(PASS|APPROVED)$' \
        || fail_with "self-eval.verdict not PASS"
    fi
    ;& # fall through

  rendered)
    [ -f "$PROJ/edit/preview.mp4" ] || [ -f "$PROJ/edit/final.mp4" ] || fail_with "no preview.mp4 or final.mp4"
    # Duration check against EDL expectation
    if [ -f "$PROJ/edit/edl.json" ]; then
      expected=$(jq -r '.total_duration_s // empty' "$PROJ/edit/edl.json")
      out="$PROJ/edit/preview.mp4"
      [ -f "$out" ] || out="$PROJ/edit/final.mp4"
      if [ -f "$out" ] && [ -n "$expected" ]; then
        actual=$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$out" 2>/dev/null || echo 0)
        # tolerance = 2s OR 5% of expected, whichever larger
        tol=$(awk -v e="$expected" 'BEGIN{t=e*0.05; if (t<2) t=2; print t}')
        delta=$(awk -v a="$actual" -v e="$expected" 'BEGIN{d=a-e; if (d<0) d=-d; print d}')
        within=$(awk -v d="$delta" -v t="$tol" 'BEGIN{print (d<=t)?1:0}')
        [ "$within" = "1" ] || fail_with "rendered duration ${actual}s differs from EDL expected ${expected}s (tol ${tol}s)"
      fi
    fi
    ;& # fall through

  audio-finalized)
    [ -f "$PROJ/edit/master.srt" ] || fail_with "master.srt missing"
    ;& # fall through

  overlays-applied)
    need=$(jq -r '.overlays | length // 0' "$MANIFEST" 2>/dev/null)
    if [ "${need:-0}" -gt 0 ]; then
      rendered_count=$(find "$PROJ/edit/animations" -name 'render.mp4' -o -name 'render.webm' 2>/dev/null | wc -l)
      [ "$rendered_count" -ge "$need" ] || fail_with "only $rendered_count/$need overlay renders present"
    fi
    ;& # fall through

  cuts-extracted)
    if [ -d "$PROJ/edit/clips_graded" ]; then
      ranges=$(jq -r '.ranges | length // 0' "$PROJ/edit/edl.json" 2>/dev/null)
      clips=$(ls "$PROJ/edit/clips_graded"/*.mp4 2>/dev/null | wc -l)
      [ "${clips:-0}" -ge "${ranges:-0}" ] || fail_with "only $clips/${ranges:-0} per-segment clips extracted"
    else
      fail_with "edit/clips_graded/ missing"
    fi
    ;& # fall through

  edl-built)
    [ -f "$PROJ/edit/edl.json" ] || fail_with "edit/edl.json missing"
    if [ -f "$PROJ/edit/edl.json" ]; then
      jq empty "$PROJ/edit/edl.json" 2>/dev/null || fail_with "edl.json is not valid JSON"
    fi
    ;& # fall through

  strategy-confirmed)
    [ -f "$PROJ/docs/strategy.md" ] || fail_with "docs/strategy.md missing"
    approved=$(jq -r '.strategy.approved // false' "$MANIFEST" 2>/dev/null)
    [ "$approved" = "true" ] || fail_with "manifest.strategy.approved is not true"
    ;& # fall through

  inventoried)
    [ -f "$PROJ/edit/takes_packed.md" ] || fail_with "edit/takes_packed.md missing"
    inputs=$(jq -r '.inputs | length // 0' "$MANIFEST" 2>/dev/null)
    [ "${inputs:-0}" -gt 0 ] || fail_with "manifest.inputs[] is empty"
    ;& # fall through

  input-received)
    [ -d "$PROJ/raw" ] || [ -L "$PROJ/raw" ] || fail_with "raw/ symlink or dir missing"
    ;;

  *) echo "unknown stage: $STAGE" >&2; exit 2 ;;
esac

if [ "$fail" -gt 0 ]; then
  printf '%s: %d gate(s) failed\n' "$STAGE" "$fail" >&2
  exit 1
fi

printf '%s: all gates pass\n' "$STAGE"
exit 0
