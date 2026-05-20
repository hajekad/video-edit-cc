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

   **`--preview`** (default if no flag) — base render, then drawtext subs:
   ```bash
   python /agents/video-use/helpers/render.py \
       /work/$1/edit/edl.json --preview --no-subtitles \
       -o /work/$1/edit/preview_base.mp4
   /opt/claude-config/tools/burn-subtitles \
       /work/$1/edit/preview_base.mp4 \
       /work/$1/edit/master.srt \
       /work/$1/edit/preview.mp4
   ```

   **`--final`** — same two-step, at delivery spec:
   ```bash
   width=$(jq -r '.output_spec.width // 1920' manifest.json)
   height=$(jq -r '.output_spec.height // 1080' manifest.json)
   fps=$(jq -r '.output_spec.fps // 30' manifest.json)
   codec=$(jq -r '.output_spec.codec // "h264_nvenc"' manifest.json)
   python /agents/video-use/helpers/render.py \
       /work/$1/edit/edl.json --no-subtitles \
       --width "$width" --height "$height" --fps "$fps" --codec "$codec" \
       -o /work/$1/edit/final_base.mp4
   /opt/claude-config/tools/burn-subtitles \
       /work/$1/edit/final_base.mp4 \
       /work/$1/edit/master.srt \
       /work/$1/edit/final.mp4
   ```

3a. **Multi-variant delivery — use build-variants, not hand-rolled.**
    When `manifest.delivery.variants[]` has more than one entry, the
    variants MUST be produced via
    `/opt/claude-config/tools/build-variants`. Hand-rolled files like
    `internal_review.mp4` / `platform_clean.mp4` are rejected by
    pipeline-gates because they lack the `<slug>_INTERNAL_REVIEW.mp4`
    / `<slug>_CLEAN_FOR_UI_MUSIC.mp4` suffix the harness depends on for:
    - file detection during delivery verification
    - mute-variant audio-policy verification (ffprobe peak < -38 dB)
    - downstream tooling that searches by suffix
    Command shape:
    ```bash
    /opt/claude-config/tools/build-variants "$SLUG" \
        /work/$1/edit/final.mp4 \
        /assets/$1/output/
    ```
    The tool reads `manifest.delivery.variants[]` + `manifest.music.mode`
    and routes per the variant's audio policy.

4. **Hard rules** (split between render.py and burn-subtitles):
   - Subtitles applied LAST — guaranteed by running burn-subtitles AFTER render.py
   - Per-segment extracts concatenated with `-c copy` (lossless)
   - Overlays use `setpts=PTS-STARTPTS+T/TB`
   - 30ms audio fades preserved at segment boundaries
   - drawtext font size is in output pixels, no PlayResY scaling surprises

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
