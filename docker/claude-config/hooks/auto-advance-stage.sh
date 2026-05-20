#!/usr/bin/env bash
# auto-advance-stage.sh — bump manifest.stage to match on-disk artifacts.
#
# Smoke test #2 shipped a 30-second cut with both variants, fcpxml, music
# cues, and README, while manifest.stage was still `input-received`. The
# loop hook reads manifest.stage to pick the next directive, so it kept
# pushing the agent back into inventory/transcribe even though the deliverable
# was complete. This script closes that gap: it walks the artifact ladder
# from the highest stage down, finds the highest stage whose evidence is
# present on disk, and updates the manifest.
#
# Invoked by loop-not-done.sh at the start of every Stop event, before the
# next-action dispatch. Side effect: writes the previous stage and a reason
# to `.stage_advanced_by` so the user can audit.
#
# Usage:
#   auto-advance-stage.sh <project-slug>

set -eo pipefail

WORK_ROOT="${FSH_WORK_ROOT:-/work}"
ID="${1:?usage: auto-advance-stage.sh <project-slug>}"
PROJ="$WORK_ROOT/$ID"
M="$PROJ/manifest.json"
[ -f "$M" ] || exit 0  # nothing to advance

prev_stage=$(jq -r '.stage // "input-received"' "$M" 2>/dev/null)
slug=$(jq -r '.slug // .id // empty' "$M" 2>/dev/null)
asset_out=$(jq -r '.output_path // empty' "$M" 2>/dev/null)
[ -n "$asset_out" ] || asset_out="/assets/$slug/output"

# Each function returns 0 if the artifacts for its stage are present.
has_input_received()    { [ -d "$PROJ/raw" ] || [ -L "$PROJ/raw" ]; }
has_inventoried()       { [ -f "$PROJ/edit/takes_packed.md" ] && [ -f "$PROJ/docs/audience_research.md" ]; }
has_strategy_confirmed(){ [ -f "$PROJ/docs/strategy.md" ] && [ "$(jq -r '.brief_intent.derived // false' "$M" 2>/dev/null)" = "true" ]; }
has_edl_built()         { [ -f "$PROJ/edit/edl.json" ] || [ -f "$PROJ/edit/build_segments.sh" ] || [ -f "$PROJ/edit/concat_list.txt" ]; }
has_cuts_extracted()    { [ -d "$PROJ/edit/clips_graded" ] && [ "$(ls "$PROJ/edit/clips_graded"/*.mp4 2>/dev/null | wc -l)" -gt 0 ]; }
has_overlays_applied()  { [ -f "$PROJ/edit/timeline_subs.mp4" ] || [ -f "$PROJ/edit/_overlaid_vertical.mp4" ] || [ -f "$PROJ/edit/_overlaid_preview.mp4" ]; }
has_audio_finalized()   {
  # master.srt OR an explicit no-dialogue note OR docs/music_cues.md when music.mode != none
  [ -f "$PROJ/edit/master.srt" ] || [ -f "$PROJ/edit/subtitles.ass" ] || [ -f "$PROJ/docs/music_cues.md" ]
}
has_rendered()          {
  [ -f "$PROJ/edit/preview.mp4" ] || [ -f "$PROJ/edit/final.mp4" ] || \
  [ -f "$PROJ/edit/internal_review.mp4" ] || [ -f "$PROJ/edit/platform_clean.mp4" ] || \
  [ -f "$PROJ/edit/timeline_subs.mp4" ]
}
has_self_eval_passed()  {
  [ -f "$PROJ/.claude/state/self-eval.verdict" ] || \
  [ -d "$PROJ/edit/verify" ] && [ "$(ls "$PROJ/edit/verify"/*.jpg 2>/dev/null | wc -l)" -gt 0 ]
}
has_delivered()         {
  [ -d "$asset_out" ] && {
    # variant flow OR legacy final.mp4
    ls "$asset_out"/*"_INTERNAL_REVIEW".mp4 >/dev/null 2>&1 || \
    ls "$asset_out"/*"_CLEAN_FOR_UI_MUSIC".mp4 >/dev/null 2>&1 || \
    [ -f "$asset_out/final.mp4" ] || \
    [ -f "$asset_out/internal_review.mp4" ] || \
    [ -f "$asset_out/platform_clean.mp4" ]
  }
}

# Walk highest → lowest. Stop at the first that's true.
detect_stage() {
  if has_delivered;        then echo "delivered"; return; fi
  if has_self_eval_passed; then echo "self-eval-passed"; return; fi
  if has_rendered;         then echo "rendered"; return; fi
  if has_audio_finalized;  then echo "audio-finalized"; return; fi
  if has_overlays_applied; then echo "overlays-applied"; return; fi
  if has_cuts_extracted;   then echo "cuts-extracted"; return; fi
  if has_edl_built;        then echo "edl-built"; return; fi
  if has_strategy_confirmed; then echo "strategy-confirmed"; return; fi
  if has_inventoried;      then echo "inventoried"; return; fi
  if has_input_received;   then echo "input-received"; return; fi
  echo "input-received"
}

new_stage=$(detect_stage)

# Stage ordering for comparison. Only advance forward — never roll back.
stage_rank() {
  case "$1" in
    input-received)     echo 0 ;;
    inventoried)        echo 1 ;;
    strategy-confirmed) echo 2 ;;
    edl-built)          echo 3 ;;
    cuts-extracted)     echo 4 ;;
    overlays-applied)   echo 5 ;;
    audio-finalized)    echo 6 ;;
    rendered)           echo 7 ;;
    self-eval-passed)   echo 8 ;;
    delivered)          echo 9 ;;
    *)                  echo -1 ;;
  esac
}

prev_rank=$(stage_rank "$prev_stage")
new_rank=$(stage_rank "$new_stage")

if [ "$new_rank" -gt "$prev_rank" ]; then
  NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  jq --arg s "$new_stage" --arg p "$prev_stage" --arg t "$NOW" \
     '.stage = $s | .stage_advanced_by = ((.stage_advanced_by // []) + [{from: $p, to: $s, at: $t, by: "auto-advance-stage.sh"}])' \
     "$M" > "$M.tmp" && mv "$M.tmp" "$M"
  echo "auto-advance-stage: $prev_stage -> $new_stage" >&2

  # On rendered → delivered (or any transition that reaches delivered),
  # auto-stage /work/<slug>/output/ → /assets/<id>/output/ if not already
  # there. Smoke #3 left 14 mp4s sitting in /work/<slug>/output/ because
  # the agent never copied them over.
  if [ "$new_stage" = "delivered" ]; then
    src_dir="$PROJ/output"
    if [ -d "$src_dir" ] && [ -d "$asset_out" ] || mkdir -p "$asset_out" 2>/dev/null; then
      # Only stage if there's something to stage AND the asset dir is empty-or-stale
      if [ -n "$(ls -A "$src_dir" 2>/dev/null)" ]; then
        # Use rsync to be idempotent (skips identical files via checksum)
        if command -v rsync >/dev/null 2>&1; then
          rsync -a --update "$src_dir"/ "$asset_out"/ 2>&1 | head -3 >&2
        else
          cp -ru "$src_dir"/. "$asset_out"/ 2>&1 | head -3 >&2
        fi
        echo "auto-stage: $src_dir/ -> $asset_out/" >&2
      fi
    fi
  fi
fi

exit 0
