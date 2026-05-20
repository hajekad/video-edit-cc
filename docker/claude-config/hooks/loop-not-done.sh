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

# Slugify an asset id (turn "Q2-2026/PyrolyzaKveten" into
# "q2-2026-pyrolyzakveten"); kept in sync with scaffold-project.sh.
slugify_id() {
  printf '%s' "$1" | tr '[:upper:]/' '[:lower:]-'
}

# True if a directory looks like a "leaf" project (has raw/ or prompt.txt
# or contains media files directly, or nested folders that contain media).
looks_like_project() {
  local d="$1"
  [ -d "$d/raw" ] && [ -n "$(ls -A "$d/raw" 2>/dev/null)" ] && return 0
  [ -f "$d/prompt.txt" ] && return 0
  # Quick scan for media right under d (depth 1).
  local hit
  hit=$(find "$d" -maxdepth 2 -mindepth 1 \
          \( -iname '*.mp4' -o -iname '*.mov' -o -iname '*.mkv' \
          -o -iname '*.webm' -o -iname '*.avi' -o -iname '*.m4v' \
          -o -iname '*.wav' -o -iname '*.mp3' -o -iname '*.flac' \
          -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \
          -o -iname '*.heic' -o -iname '*.cr2' -o -iname '*.cr3' \
          -o -iname '*.arw' -o -iname '*.nef' -o -iname '*.dng' \) \
          -print -quit 2>/dev/null)
  [ -n "$hit" ]
}

# Print pending /assets/<id>/ projects that have media but no corresponding
# /work/<slug>/. Walks one level deep so /assets/Q2-2026/PyrolyzaKveten/
# is discovered as the id "Q2-2026/PyrolyzaKveten".
unscaffolded_assets() {
  shopt -s nullglob
  for d in "$ASSETS_ROOT"/*/; do
    [ -d "$d" ] || continue
    local parent
    parent=$(basename "$d")
    [ "$parent" = "lost+found" ] && continue
    if looks_like_project "$d"; then
      local slug
      slug=$(slugify_id "$parent")
      [ -d "$WORK_ROOT/$slug" ] && continue
      printf '%s\n' "$parent"
      continue
    fi
    # Parent has no media of its own — look for nested leaf projects.
    for c in "$d"*/; do
      [ -d "$c" ] || continue
      local child id slug
      child=$(basename "$c")
      id="$parent/$child"
      slug=$(slugify_id "$id")
      [ -d "$WORK_ROOT/$slug" ] && continue
      if looks_like_project "$c"; then
        printf '%s\n' "$id"
      fi
    done
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
      printf 'Good. Now focus on this: run /inventory %s — scaffold, ffprobe, transcribe, AND run the three-pass brief-interpretation read (surface / signal / audience) per /docs/BRIEF_INTERPRETATION.md. Record platform / audience / brand / music_mode / variants into manifest.brief_intent with WHY lines. Set manifest.brief_intent.derived = true before advancing.\n' "$id" ;;
    transcribe)
      printf 'Good. Now focus on this: transcribe every source in /work/%s/raw/ via the baked WhisperX large-v3 (FSH_WHISPER_MODEL_DIR=/opt/whisper-models) into /work/%s/edit/transcripts/<name>.json, then pack into edit/takes_packed.md. Cache per source.\n' "$id" "$id" ;;
    propose-strategy)
      printf 'Good. Now focus on this: read /work/%s/manifest.json brief_intent block + /work/%s/edit/takes_packed.md + the persona constraints from /agents/fsh-music-mood-bridge/personas.yaml. Write a strategy proposal to /work/%s/docs/strategy.md that BUILDS on brief_intent (platform/audience/brand/music_mode/variants) and adds: arc, take choices, cut direction, animation plan, grade, subtitle style, length. One WHY line per decision. Self-approve. The user audits on return.\n' "$id" "$id" "$id" ;;
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

# 1. Any /assets/<id>/ without a /work/<slug>/ workspace? Ingest it.
unscaffolded=$(unscaffolded_assets | head -1)
if [ -n "$unscaffolded" ]; then
  slug=$(slugify_id "$unscaffolded")
  printf 'Good. Now focus on this: a new project "%s" landed in /assets/%s/. Run scaffold-project.sh "%s" (it accepts the nested id, writes manifest with slug=%s, and symlinks raw safely). Then run inventory.\n' "$unscaffolded" "$unscaffolded" "$unscaffolded" "$slug" >&2
  exit 2
fi

# 2. Any active project? First, auto-advance the manifest stage so the
#    loop can't get stuck at input-received while downstream artifacts
#    already exist on disk. Then dispatch its next action.
active=$(active_project)
if [ -n "$active" ]; then
  /opt/claude-config/hooks/auto-advance-stage.sh "$active" 2>&1 | head -3 >&2 || true
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
