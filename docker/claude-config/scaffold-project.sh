#!/usr/bin/env bash
# scaffold-project.sh — create /work/<slug>/ from /assets/<id>/.
#
# Idempotent: re-running on an existing project repairs missing pieces
# without clobbering existing artifacts. Hard rules:
#   - NEVER mutate /assets/<id>/raw/ contents — only symlinks.
#   - NEVER auto-extract zips. Real client deliveries arrive as 10+ GB
#     archived masters; blind unzip filled the disk during smoke testing.
#     Zips are quarantined into /assets/<id>/deliveries/ and the user
#     decides what to extract.
#
# Asset ID forms accepted:
#   pyrolyza-kveten              -> /work/pyrolyza-kveten/
#   Q2-2026/PyrolyzaKveten       -> /work/q2-2026-pyrolyzakveten/
#                                    (slug = parent + "-" + child, lowercased)
#
# Usage:
#   scaffold-project.sh <project-id>
#
# Exit codes:
#   0  scaffolded (or already scaffolded — idempotent OK)
#   1  no /assets/<id>/ directory
#   2  bad input

set -eo pipefail

ID="${1:?usage: scaffold-project.sh <project-id>}"

# Validate: at most one slash, no dot-segments.
case "$ID" in
  .|..|*'..'*|/*|*/) echo "invalid id: $ID" >&2; exit 2 ;;
esac
slashes=$(awk -F/ '{print NF-1}' <<<"$ID")
if [ "$slashes" -gt 1 ]; then
  echo "invalid id: $ID (max one slash, e.g. Q2-2026/PyrolyzaKveten)" >&2
  exit 2
fi

# Slug = lowercase, slashes→dashes, no other transforms.
SLUG=$(printf '%s' "$ID" | tr '[:upper:]/' '[:lower:]-')

ASSET="/assets/$ID"
PROJ="/work/$SLUG"

[ -d "$ASSET" ] || { echo "no /assets/$ID/ — drop input there first" >&2; exit 1; }

# 1. Zip safety — quarantine, never extract.
shopt -s nullglob
zip_found=0
for z in "$ASSET"/*.zip; do
  [ -f "$z" ] || continue
  zip_found=1
  mkdir -p "$ASSET/deliveries"
  if [ ! -f "$ASSET/deliveries/$(basename "$z")" ]; then
    mv "$z" "$ASSET/deliveries/"
  fi
done
shopt -u nullglob
if [ "$zip_found" = "1" ]; then
  echo "scaffold: quarantined zip(s) into $ASSET/deliveries/ — agent decides if extract is wanted (filename / size / sample first)" >&2
fi

# 2. Normalize input layout. If files are loose at /assets/<id>/ root
#    (not in raw/ already), sweep media into raw/. Never touch
#    pre-existing nested folder layouts — those are the user's own
#    structure (HiRes/, LowRes/, "videa zdrojaky", etc.) and we just
#    symlink to <id> root instead.
if [ ! -d "$ASSET/raw" ]; then
  shopt -s nullglob nocaseglob
  loose_media=("$ASSET"/*.{mp4,mov,mkv,webm,avi,m4v,wav,mp3,flac,m4a,jpg,jpeg,png,heic,cr2,cr3,arw,nef,dng,raw})
  shopt -u nullglob nocaseglob
  if [ "${#loose_media[@]}" -gt 0 ]; then
    mkdir -p "$ASSET/raw"
    for f in "${loose_media[@]}"; do
      [ -f "$f" ] && mv "$f" "$ASSET/raw/"
    done
  fi
fi

# Decide what to symlink as /work/<slug>/raw:
#   - $ASSET/raw if it exists (the canonical case after the sweep above)
#   - else $ASSET itself, so the agent can see the user's nested layout
RAW_TARGET="$ASSET"
[ -d "$ASSET/raw" ] && RAW_TARGET="$ASSET/raw"

# 3. Create workspace skeleton.
mkdir -p "$PROJ"/edit/{transcripts,clips_graded,animations,verify} \
         "$PROJ"/docs/issues \
         "$PROJ"/.claude/state/issue-review \
         "$ASSET"/output

# 4. Symlink raw — sources stay in /assets, never mutated.
ln -sfn "$RAW_TARGET" "$PROJ/raw"

# 5. Mirror hooks + settings from the baked claude-config.
ln -sfn /opt/claude-config/hooks "$PROJ/.claude/hooks"
ln -sfn /opt/claude-config/settings.json "$PROJ/.claude/settings.json"

# 6. DO NOT init per-project git. The parent /work/.git is the agent's
#    "pacifier" git (per the project-anchor rationale documented in
#    /work/README.md). A per-project .git/ here would make the outer
#    work/ repo treat this subdir as an embedded repo / gitlink, which
#    breaks the curated text-slice tracking pattern in /work/.gitignore.
#    The agent's auto-commit hook commits against the parent /work/.git
#    against this project's path.
if [ -d "$PROJ/.git" ]; then
  echo "scaffold: removing stale per-project .git (parent /work/.git is the tracking surface)" >&2
  rm -rf "$PROJ/.git"
fi

# 7. Read user prompt if present.
PROMPT=""
if [ -f "$ASSET/prompt.txt" ]; then
  PROMPT=$(head -c 4096 "$ASSET/prompt.txt")
fi

# 8. Initialize manifest.json if missing. Track BOTH the original asset
#    id (with slash) and the flat slug — downstream tools need either.
MANIFEST="$PROJ/manifest.json"
if [ ! -f "$MANIFEST" ]; then
  NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  jq -n \
    --arg id "$ID" \
    --arg slug "$SLUG" \
    --arg asset_path "$ASSET" \
    --arg now "$NOW" \
    --arg prompt "$PROMPT" \
    '{
      id: $id,
      slug: $slug,
      asset_path: $asset_path,
      stage: "input-received",
      created: $now,
      prompt: $prompt,
      inputs: [],
      brief_intent: {
        derived: false,
        platforms: [],
        audience: null,
        brand: null,
        delivery_pattern: null,
        why: null
      },
      strategy: { approved: false },
      overlays: [],
      subtitles: { style: "drawtext-bold-lower-third", language: null },
      grade: "none",
      audience_persona: null,
      music: {
        mode: null,
        proposed_track: null,
        cues_path: null,
        license_proof: null
      },
      brand: {
        name: null,
        official_press_url: null,
        logo_path: null,
        primary_color: null,
        secondary_color: null,
        voice: null
      },
      output_spec: { width: 1920, height: 1080, fps: 30, codec: "h264_nvenc" },
      delivery: {
        preset: null,
        variants: [],
        mp4: true,
        nle_xml: true
      }
    }' > "$MANIFEST"
fi

# 9. Flat-path symlink for tooling that only handles /assets/<slug>/.
#    Only create when nested (slug != id) and the slug path doesn't
#    already exist as a real directory.
if [ "$SLUG" != "$ID" ] && [ ! -e "/assets/$SLUG" ]; then
  ln -sfn "$ASSET" "/assets/$SLUG"
fi

# 10. Initialize project.md if missing.
PROJECT_MD="$PROJ/project.md"
if [ ! -f "$PROJECT_MD" ]; then
  NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  cat > "$PROJECT_MD" <<EOF
# Project: $ID

Slug: $SLUG
Asset path: $ASSET
Created: $NOW

## Session 1 — $NOW

**Prompt:** ${PROMPT:-(none provided)}

**Inputs:** $(ls "$PROJ/raw" 2>/dev/null | wc -l) entry(ies) visible under raw/.

**Stage at session start:** input-received

EOF
fi

# 11. Done. Print the project root for chaining.
printf '%s\n' "$PROJ"
