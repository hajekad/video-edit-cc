---
description: Render the current project. --preview (720p, fast) or --final (delivery spec).
argument-hint: <project-name> [--preview|--final]
---

# /render — produce video output

Render the project's `edit/edl.json` + composites into MP4. Two modes:
`--preview` (720p, fast) and `--final` (manifest.output_spec).

## What to do

1. **cd** `/work/$1/`. Verify `manifest.stage` is at least `audio-finalized`.
   If not, run the loop and let it walk forward.

2. **Verify gates** for the prerequisite stages:
   ```bash
   /opt/claude-config/hooks/pipeline-gates.sh "$1" cuts-extracted
   /opt/claude-config/hooks/pipeline-gates.sh "$1" overlays-applied
   /opt/claude-config/hooks/pipeline-gates.sh "$1" audio-finalized
   ```
   If any fail, surface the gap to the user; do NOT render.

3. **Compose the render command** based on mode:

   **`--preview`** (default if no flag):
   ```bash
   # 720p, subtitles last, fast
   python /agents/video-use/helpers/render.py \
       /work/$1/edit/edl.json \
       --preview \
       -o /work/$1/edit/preview.mp4
   ```

   **`--final`**:
   ```bash
   # Read output_spec from manifest
   width=$(jq -r '.output_spec.width // 1920' manifest.json)
   height=$(jq -r '.output_spec.height // 1080' manifest.json)
   fps=$(jq -r '.output_spec.fps // 30' manifest.json)
   codec=$(jq -r '.output_spec.codec // "h264_nvenc"' manifest.json)
   python /agents/video-use/helpers/render.py \
       /work/$1/edit/edl.json \
       --width "$width" --height "$height" --fps "$fps" --codec "$codec" \
       -o /work/$1/edit/final.mp4
   ```

4. **Hard rules** (enforced by `render.py` but verify post-render):
   - Subtitles applied LAST in the filter chain
   - Per-segment extracts concatenated with `-c copy` (lossless)
   - Overlays use `setpts=PTS-STARTPTS+T/TB`
   - 30ms audio fades preserved at segment boundaries

5. **Update manifest** to `stage: rendered` and commit.

6. For `--final`: also copy outputs into `/assets/$1/output/` and, if
   `manifest.delivery.nle_xml`, generate buttercut XML:
   ```bash
   cp /work/$1/edit/final.mp4 /assets/$1/output/final.mp4
   ruby -I/agents/buttercut/lib /agents/buttercut/scripts/export.rb \
       --library /work/$1 --output /assets/$1/output/
   ```
   Then `stage: delivered`.

## What NOT to do

- Don't render without verifying the gates. A render on a stale EDL
  wastes 2-5 minutes of GPU time.
- Don't bypass `render.py` to call ffmpeg directly — you'll lose the
  per-segment extract + lossless concat invariant.
- Don't render `--final` until `--preview` has passed self-eval.
