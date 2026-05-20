#!/usr/bin/env bash
# Stop hook — continuous-worker loop for the FotoStudioH video pipeline.
# Adapted from nix-zeneca-model's matrix/work-item loop. Replaces the
# `make audit/test-full/conformance` gates with video-pipeline stage
# detection driven by manifest.json + on-disk artifacts.
#
# Done condition: no active project AND no un-ingested inputs in /assets/.
# Active project = any /work/<id>/ whose manifest.stage != "delivered".
#
# If multiple active projects, picks the most-recently-modified.
# Forbidden self-stops: "natural break", "wrap up", "next time". If done
# is false, the next action is work.

set -u

WORK_ROOT="${FSH_WORK_ROOT:-/work}"
ASSETS_ROOT="${FSH_ASSETS_ROOT:-/assets}"

# Drain stdin so the hook plumbing doesn't break.
cat >/dev/null

# ---- helpers ---------------------------------------------------------------

# Print the most-recently-modified active project id (manifest.stage !=
# delivered). Empty if none.
active_project() {
  local newest="" newest_mtime=0
  shopt -s nullglob
  for d in "$WORK_ROOT"/*/; do
    [ -d "$d" ] || continue
    local id mtime stage
    id=$(basename "$d")
    [ "$id" = ".queue" ] && continue
    if [ -f "$d/manifest.json" ]; then
      stage=$(jq -r '.stage // "input-received"' "$d/manifest.json" 2>/dev/null || echo "input-received")
      [ "$stage" = "delivered" ] && continue
    fi
    mtime=$(stat -c %Y "$d" 2>/dev/null || echo 0)
    if [ "$mtime" -gt "$newest_mtime" ]; then
      newest_mtime=$mtime
      newest="$id"
    fi
  done
  shopt -u nullglob
  printf '%s' "$newest"
}

# Print pending /assets/<name>/ projects that have raw files but no
# corresponding /work/<id>/. Caller emits the workspace-scaffold instruction.
unscaffolded_assets() {
  shopt -s nullglob
  for d in "$ASSETS_ROOT"/*/; do
    [ -d "$d" ] || continue
    local name
    name=$(basename "$d")
    # Skip if a /work/<name>/ already exists (1:1 by default).
    [ -d "$WORK_ROOT/$name" ] && continue
    # Only flag if there's something in raw/ or a prompt.txt
    if [ -d "$d/raw" ] && [ -n "$(ls -A "$d/raw" 2>/dev/null)" ]; then
      printf '%s\n' "$name"
    elif [ -f "$d/prompt.txt" ]; then
      printf '%s\n' "$name"
    fi
  done
  shopt -u nullglob
}

# Given a project id, return the next action keyword based on its stage +
# on-disk artifacts.
next_action_for() {
  local id="$1"
  local proj="$WORK_ROOT/$id"
  local manifest="$proj/manifest.json"

  if [ ! -f "$manifest" ]; then
    printf 'inventory'
    return
  fi

  local stage
  stage=$(jq -r '.stage // "input-received"' "$manifest" 2>/dev/null)

  case "$stage" in
    input-received|inventoried)
      [ ! -f "$proj/edit/takes_packed.md" ] && { printf 'transcribe'; return; }
      printf 'propose-strategy'
      ;;
    strategy-confirmed)
      [ ! -f "$proj/edit/edl.json" ] && { printf 'build-edl'; return; }
      printf 'extract-cuts'
      ;;
    edl-built)
      printf 'extract-cuts'
      ;;
    cuts-extracted)
      # If manifest says overlays are planned, check they're rendered
      local need_overlays
      need_overlays=$(jq -r '.overlays | length // 0' "$manifest" 2>/dev/null)
      if [ "${need_overlays:-0}" -gt 0 ]; then
        local rendered
        rendered=$(find "$proj/edit/animations" -name 'render.mp4' -o -name 'render.webm' 2>/dev/null | wc -l)
        if [ "$rendered" -lt "$need_overlays" ]; then
          printf 'build-animations'
          return
        fi
      fi
      printf 'apply-overlays'
      ;;
    overlays-applied)
      [ ! -f "$proj/edit/master.srt" ] && { printf 'build-subtitles'; return; }
      printf 'render-preview'
      ;;
    audio-finalized)
      printf 'render-preview'
      ;;
    rendered)
      printf 'self-eval'
      ;;
    self-eval-passed)
      printf 'deliver'
      ;;
    delivered)
      printf 'done'
      ;;
    *)
      printf 'inventory'
      ;;
  esac
}

# Render a human-grade "Good. Now focus on this: ..." sentence for a given
# next-action keyword and project id.
action_sentence() {
  local action="$1" id="$2"
  case "$action" in
    inventory)
      printf 'Good. Now focus on this: scaffold /work/%s/ (mkdir edit/, manifest.json with stage=input-received, raw symlink to /assets/%s/raw/). Then ffprobe every source and write the inputs[] array.\n' "$id" "$id" ;;
    transcribe)
      printf 'Good. Now focus on this: transcribe every source in /work/%s/raw/ via WhisperX on GPU into /work/%s/edit/transcripts/<name>.json, then pack into edit/takes_packed.md.\n' "$id" "$id" ;;
    propose-strategy)
      printf 'Good. Now focus on this: read /work/%s/edit/takes_packed.md and the user prompt in /assets/%s/prompt.txt (if present). Write a 4-8 sentence strategy proposal to /work/%s/docs/strategy.md and ask the user to confirm. Set manifest.stage=strategy-confirmed only after explicit user OK.\n' "$id" "$id" "$id" ;;
    build-edl)
      printf 'Good. Now focus on this: spawn the editor sub-agent (Agent tool, general-purpose) with the brief in /work/%s/docs/strategy.md and takes_packed.md. Produce /work/%s/edit/edl.json — word-boundary-snapped ranges, padded 30-200ms, beat labels and quotes. Update manifest.stage=edl-built.\n' "$id" "$id" ;;
    extract-cuts)
      printf 'Good. Now focus on this: per-segment extract from /work/%s/edit/edl.json into /work/%s/edit/clips_graded/. Apply grade + 30ms audio fades per segment (Hard Rules 2, 3). Update manifest.stage=cuts-extracted.\n' "$id" "$id" ;;
    build-animations)
      printf 'Good. Now focus on this: spawn parallel Agent sub-agents (one per slot in /work/%s/edit/animations/slot_*) — each builds ONE overlay with the spec from manifest.overlays[]. Use HyperFrames / Remotion / Manim / PIL per slot. Verify render.mp4 duration + dimensions via ffprobe.\n' "$id" ;;
    apply-overlays)
      printf 'Good. Now focus on this: composite the rendered animations in /work/%s/edit/animations/slot_*/render.mp4 onto the per-segment extracts using setpts=PTS-STARTPTS+T/TB (Hard Rule 4). Update manifest.stage=overlays-applied.\n' "$id" ;;
    build-subtitles)
      printf 'Good. Now focus on this: build /work/%s/edit/master.srt using output-timeline offsets (Hard Rule 5). Apply the style preset from manifest.subtitles. Update manifest.stage=audio-finalized.\n' "$id" ;;
    render-preview)
      printf 'Good. Now focus on this: render /work/%s/edit/preview.mp4 at 720p via render.py with subtitles LAST (Hard Rule 1). Update manifest.stage=rendered.\n' "$id" ;;
    self-eval)
      printf 'Good. Now focus on this: run timeline_view at every cut boundary (±1.5s) on the rendered output in /work/%s/edit/preview.mp4. Check for visual jumps, audio pops, hidden subtitles, overlay mis-alignment. Cap at 3 fix passes. Write the verdict to /work/%s/.claude/state/self-eval.verdict.\n' "$id" "$id" ;;
    deliver)
      printf 'Good. Now focus on this: render final /work/%s/edit/final.mp4 at delivery resolution, AND export buttercut NLE XML if the project specs that. Copy outputs into /assets/%s/output/. Update manifest.stage=delivered.\n' "$id" "$id" ;;
    *)
      printf 'Good. Now focus on this: unrecognized action %s for project %s — investigate manifest.json and continue from the appropriate stage.\n' "$action" "$id" ;;
  esac
}

# ---- main dispatch ---------------------------------------------------------

# 1. Any /assets/<name>/ without a /work/<name>/ workspace? Ingest it.
unscaffolded=$(unscaffolded_assets | head -1)
if [ -n "$unscaffolded" ]; then
  printf 'Good. Now focus on this: a new project "%s" landed in /assets/%s/. Scaffold /work/%s/ (mkdir edit/, write manifest.json with stage=input-received, symlink raw -> /assets/%s/raw/), git init the workspace, and run inventory.\n' "$unscaffolded" "$unscaffolded" "$unscaffolded" "$unscaffolded" >&2
  exit 2
fi

# 2. Any active project? Dispatch its next action.
active=$(active_project)
if [ -n "$active" ]; then
  action=$(next_action_for "$active")
  if [ "$action" = "done" ]; then
    # All-delivered fallthrough — treat as no-active. Keep walking.
    :
  else
    action_sentence "$action" "$active" >&2
    exit 2
  fi
fi

# 3. Idle. The fsh-agent loop is project-driven, not toolchain-driven:
#    when no /assets/ drop is pending and no /work/<id>/ is mid-flight, the
#    agent stops and waits. /docs/issues/ exists for the agent to FILE
#    meta-observations during project work (toolchain bugs, capability
#    gaps), but it is NOT a queue the loop walks proactively.
printf 'No active projects and no un-ingested inputs in /assets/. Drop a folder, zip, file, or URL into /assets/<name>/ to start the next edit.\n'
exit 0
