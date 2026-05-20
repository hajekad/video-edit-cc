# Stage: rendered

Render a 720p preview for self-eval before the expensive final render.

## Entry condition

- `manifest.stage == audio-finalized`
- `edit/master.srt` exists
- `edit/clips_graded/<n>.mp4` for every EDL range

## What to do

Render via `agents/video-use/helpers/render.py` (or its FSH port). It
enforces the contract:

1. **Per-segment extracts** already exist from cuts-extracted stage.
2. **Concat with `-c copy`** — lossless, no re-encode.
3. **Composite overlays** with `setpts=PTS-STARTPTS+T/TB` (Hard Rule 4).
4. **Subtitles applied LAST** in the filter chain (Hard Rule 1).

Preview render:
```bash
python /agents/video-use/helpers/render.py \
    /work/<id>/edit/edl.json \
    --preview \
    --subtitles /work/<id>/edit/master.srt \
    -o /work/<id>/edit/preview.mp4
```

Preview = 1280x720, fast NVENC preset, CRF ~28. Should complete in
under 1× source duration on the RTX 3080 Ti.

## Gate

```bash
/opt/claude-config/hooks/pipeline-gates.sh "<id>" rendered
```

Critical checks:
- preview.mp4 exists
- ffprobe duration matches `edl.total_duration_s` within 2s OR 5%

If duration is off by more than that, something is wrong with the
concat (lossy fallback, wrong frame counts, missing segment). Fix
upstream before advancing.

## NOT YET: do not skip self-eval

The temptation: "the render looks fine, mark delivered." NO. Self-eval
is a separate stage with concrete checks. Without it, you'll ship
output with hidden audio pops, mis-aligned overlays, or subtitle clash.

## `manifest.stage = rendered`. Commit.

## Pitfalls

- **NVENC encoder errors.** Some flags differ from libx264. Use
  `-preset slow` (or `p7` in the new preset system), `-rc:v vbr -cq 18
  -b:v 0` for VBR quality. NEVER `-crf 18` with NVENC — that's libx264 syntax.
- **Concat skipped via re-encode fallback.** If render.py falls back
  to re-encode (codec mismatch between segments), you get double
  encoding. The cuts-extracted stage should have already normalized
  codec/sample rate to avoid this.
- **Subtitles burned as a layer BEFORE overlays.** Hard Rule 1
  violation. The renderer applies them last; if you hand-roll a
  filtergraph, you'll get this wrong.
- **Preview-only resolution baked into final render.** Re-check
  `manifest.output_spec` before /render --final.

## Advance to: self-eval-passed
