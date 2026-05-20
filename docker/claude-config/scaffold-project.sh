#!/usr/bin/env bash
# scaffold-project.sh — create /work/<id>/ from /assets/<id>/.
#
# Idempotent: re-running on an existing project repairs missing pieces
# without clobbering existing artifacts. Hard rule: NEVER modifies
# /assets/<id>/raw/ contents — only symlinks them.
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
case "$ID" in
  */*|.|..|*'..'*) echo "invalid id: $ID" >&2; exit 2 ;;
esac

ASSET="/assets/$ID"
PROJ="/work/$ID"

[ -d "$ASSET" ] || { echo "no /assets/$ID/ — drop input there first" >&2; exit 1; }

# 1. Normalize input layout: if files are at /assets/<id>/ root (not in raw/),
#    AND no raw/ dir exists yet, move them into raw/. If raw.zip exists, extract.
if [ ! -d "$ASSET/raw" ]; then
  # First check for a zip to extract.
  for z in "$ASSET"/*.zip; do
    [ -f "$z" ] || continue
    mkdir -p "$ASSET/raw"
    unzip -q "$z" -d "$ASSET/raw/"
    break
  done
  # Otherwise sweep media-looking files into raw/.
  if [ ! -d "$ASSET/raw" ]; then
    mkdir -p "$ASSET/raw"
    shopt -s nullglob nocaseglob
    for f in "$ASSET"/*.{mp4,mov,mkv,webm,avi,m4v,wav,mp3,flac,m4a,jpg,jpeg,png,heic}; do
      [ -f "$f" ] && mv "$f" "$ASSET/raw/"
    done
    shopt -u nullglob nocaseglob
    # If raw/ is still empty, leave it — user might be using a folder name we don't recognize.
    rmdir "$ASSET/raw" 2>/dev/null || true
  fi
fi

[ -d "$ASSET/raw" ] || { echo "no media in /assets/$ID/ — drop files into $ASSET/raw/" >&2; exit 1; }

# 2. Create workspace skeleton.
mkdir -p "$PROJ"/edit/{transcripts,clips_graded,animations,verify} \
         "$PROJ"/docs/issues \
         "$PROJ"/.claude/state/issue-review \
         "$ASSET"/output

# 3. Symlink raw — sources stay in /assets, never mutated.
ln -sfn "$ASSET/raw" "$PROJ/raw"

# 4. Mirror hooks + settings from the baked claude-config.
ln -sfn /opt/claude-config/hooks "$PROJ/.claude/hooks"
ln -sfn /opt/claude-config/settings.json "$PROJ/.claude/settings.json"

# 5. Initialize git if not already.
if [ ! -d "$PROJ/.git" ]; then
  git -C "$PROJ" init -q
  git -C "$PROJ" config commit.gpgsign false
  git -C "$PROJ" config user.email "agent@fotostudioh"
  git -C "$PROJ" config user.name "fsh-agent"
  cat > "$PROJ/.gitignore" <<'GI'
# binary outputs — keep edl.json, manifest.json, transcripts/, but NOT the renders.
edit/preview.mp4
edit/final.mp4
edit/clips_graded/*.mp4
edit/animations/*/render.mp4
edit/animations/*/render.webm
edit/verify/*.png
edit/verify/*.jpg
# but DO track structure
!edit/clips_graded/.gitkeep
!edit/animations/.gitkeep
!edit/verify/.gitkeep
GI
  touch "$PROJ/edit/clips_graded/.gitkeep" \
        "$PROJ/edit/animations/.gitkeep" \
        "$PROJ/edit/verify/.gitkeep"
fi

# 6. Read user prompt if present.
PROMPT=""
if [ -f "$ASSET/prompt.txt" ]; then
  PROMPT=$(head -c 4096 "$ASSET/prompt.txt")
fi

# 7. Initialize manifest.json if missing.
MANIFEST="$PROJ/manifest.json"
if [ ! -f "$MANIFEST" ]; then
  NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  jq -n \
    --arg id "$ID" \
    --arg now "$NOW" \
    --arg prompt "$PROMPT" \
    '{
      id: $id,
      stage: "input-received",
      created: $now,
      prompt: $prompt,
      inputs: [],
      strategy: { approved: false },
      overlays: [],
      subtitles: { style: "bold-overlay" },
      grade: "none",
      output_spec: { width: 1920, height: 1080, fps: 30, codec: "h264_nvenc" },
      delivery: { mp4: true, nle_xml: true }
    }' > "$MANIFEST"
fi

# 8. Initialize project.md if missing.
PROJECT_MD="$PROJ/project.md"
if [ ! -f "$PROJECT_MD" ]; then
  NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  cat > "$PROJECT_MD" <<EOF
# Project: $ID

Created: $NOW

## Session 1 — $NOW

**Prompt:** ${PROMPT:-(none provided)}

**Inputs:** $(ls "$PROJ/raw" 2>/dev/null | wc -l) file(s) in raw/.

**Stage at session start:** input-received

EOF
fi

# 9. Done. Print the project root for chaining.
printf '%s\n' "$PROJ"
