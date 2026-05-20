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
    # Either final.mp4 exists (single-variant flow) OR the variant pair exists.
    asset_out=$(jq -r '.output_path // empty' "$MANIFEST" 2>/dev/null)
    [ -n "$asset_out" ] || asset_out="/assets/$ID/output"
    slug=$(jq -r '.slug // .id // empty' "$MANIFEST" 2>/dev/null)

    # Variant flow: each declared variant must have a matching file with the
    # mandated suffix in the output dir.
    variant_count=$(jq -r '.delivery.variants | length // 0' "$MANIFEST" 2>/dev/null)
    if [ "${variant_count:-0}" -gt 0 ]; then
      [ -d "$asset_out" ] || fail_with "output dir $asset_out missing"
      while IFS= read -r vname; do
        case "$vname" in
          internal_review)
            ls "$asset_out"/*"_INTERNAL_REVIEW".mp4 >/dev/null 2>&1 \
              || fail_with "missing <slug>_INTERNAL_REVIEW.mp4 in $asset_out — produced via /opt/claude-config/tools/build-variants"
            ;;
          platform_clean)
            ls "$asset_out"/*"_CLEAN_FOR_UI_MUSIC".mp4 >/dev/null 2>&1 \
              || fail_with "missing <slug>_CLEAN_FOR_UI_MUSIC.mp4 in $asset_out — produced via build-variants"
            ;;
          platform_final)
            [ -f "$asset_out/${slug}.mp4" ] || [ -f "$asset_out/final.mp4" ] \
              || fail_with "missing platform_final mp4 in $asset_out (expected ${slug}.mp4 or final.mp4)"
            ;;
        esac
      done < <(jq -r '.delivery.variants[].name // empty' "$MANIFEST" 2>/dev/null)
    else
      # Legacy single-final flow.
      [ -f "$PROJ/edit/final.mp4" ] || fail_with "final.mp4 missing"
      if [ -f "$PROJ/edit/final.mp4" ]; then
        sz=$(stat -c %s "$PROJ/edit/final.mp4" 2>/dev/null || echo 0)
        [ "$sz" -lt 1048576 ] && fail_with "final.mp4 < 1MB ($sz bytes); likely truncated"
      fi
      { [ -d "$asset_out" ] && [ -f "$asset_out/final.mp4" ]; } \
        || fail_with "delivery copy missing in $asset_out/final.mp4"
    fi

    # When music.mode = internal-reference AND internal_review variant exists,
    # the audio stream MUST NOT be synthesized guide tones (sine waves). Smoke
    # test #2 invented that pattern; doctrine bans it. Quick proxy: mean
    # volume in a real music bed sits between -28 dB and -10 dB; sine guide
    # tones produce sparse spikes with long silence (mean << -40 dB).
    music_mode=$(jq -r '.music.mode // "none"' "$MANIFEST" 2>/dev/null)
    if [ "$music_mode" = "internal-reference" ]; then
      ir_path=$(ls "$asset_out"/*"_INTERNAL_REVIEW".mp4 2>/dev/null | head -1)
      if [ -n "$ir_path" ] && command -v ffmpeg >/dev/null; then
        mean=$(ffmpeg -hide_banner -nostats -i "$ir_path" -af volumedetect -vn -f null - 2>&1 | awk -F': ' '/mean_volume:/{print $2; exit}' | awk '{print $1}')
        if [ -n "$mean" ]; then
          too_quiet=$(awk -v m="$mean" 'BEGIN{print (m < -38) ? 1 : 0}')
          if [ "$too_quiet" = "1" ]; then
            fail_with "internal_review audio mean is ${mean} dB — looks like sine-tone guide track or silence, NOT proposed music. Per DROPIN_SCAFFOLD_PATTERN.md: never invent audible substitutes. Ship platform_clean only with pending_music marker."
          fi
        fi
      fi
    fi
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
    music_mode=$(jq -r '.music.mode // "none"' "$MANIFEST" 2>/dev/null)
    if [ "$music_mode" != "none" ] && [ "$music_mode" != "null" ]; then
      [ -f "$PROJ/docs/music_cues.md" ] || fail_with "docs/music_cues.md missing (required when music.mode != none — generate via /opt/claude-config/tools/music-cues-template)"
    fi
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
    derived=$(jq -r '.brief_intent.derived // false' "$MANIFEST" 2>/dev/null)
    [ "$derived" = "true" ] || fail_with "manifest.brief_intent.derived is not true — run /inventory to derive platform/audience/brand before /plan"
    ;& # fall through

  inventoried)
    [ -f "$PROJ/edit/takes_packed.md" ] || fail_with "edit/takes_packed.md missing"
    inputs=$(jq -r '.inputs | length // 0' "$MANIFEST" 2>/dev/null)
    [ "${inputs:-0}" -gt 0 ] || fail_with "manifest.inputs[] is empty"
    derived=$(jq -r '.brief_intent.derived // false' "$MANIFEST" 2>/dev/null)
    [ "$derived" = "true" ] || fail_with "manifest.brief_intent.derived is not true — inventoried stage requires the three-pass brief read (see /docs/BRIEF_INTERPRETATION.md)"
    [ -f "$PROJ/docs/audience_research.md" ] || fail_with "docs/audience_research.md missing — record persona, brand voice, audience research, and people-science levers as a first-class artifact (not just in README)"
    # Mandatory orientation decision per video source (see SOURCE_QUIRKS.md).
    # Each video input must carry at least one quirks[] entry with confirmed_by != null.
    missing_quirks=$(jq -r '[.inputs[] | select((.file // "") | test("\\.(mp4|mov|mkv|webm|avi|m4v)$"; "i")) | select(((.quirks // []) | length) == 0) | .file] | join(", ")' "$MANIFEST" 2>/dev/null)
    if [ -n "$missing_quirks" ]; then
      fail_with "video source(s) without orientation decision in manifest.inputs[].quirks[]: $missing_quirks — run /opt/claude-config/tools/orientation-check on each, record the matched quirk per /docs/SOURCE_QUIRKS.md"
    fi
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
