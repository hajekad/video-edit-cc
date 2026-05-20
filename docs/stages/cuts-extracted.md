# Stage: cuts-extracted

EDL in hand. Extract every range as a self-contained clip with grade
applied per-segment and 30ms audio fades at every boundary.

## Entry condition

- `manifest.stage == edl-built`
- `edit/edl.json` exists and validates clean
- `edit/clips_graded/` exists (empty or partial)

## What to do

For each `range` in `edl.ranges`:

1. **Extract** the segment via ffmpeg using the source path from
   `edl.sources[range.source]`. Use per-segment extract — never a
   single-pass filtergraph (Hard Rule 2):
   ```bash
   ffmpeg -ss <start> -i <source> -t <end-start> \
       -vf "<grade_chain>" \
       -af "afade=t=in:st=0:d=0.03,afade=t=out:st=<dur-0.03>:d=0.03" \
       -c:v h264_nvenc -preset slow -cq 18 -c:a aac -b:a 192k \
       edit/clips_graded/<idx>.mp4
   ```
   Use the helper in `agents/video-use/helpers/render.py` (per-range
   extract path) rather than hand-rolling. It enforces the contract.

2. **Apply grade per-segment**, not post-concat. Read
   `manifest.grade` for preset name or raw filter. Common presets:
   - `warm_cinematic` — subtle teal/orange split, desaturated
   - `neutral_punch` — contrast + S-curve, no hue shift
   - `none` — straight copy
   For anything else, accept a raw ffmpeg filter string from the
   manifest.

3. **30ms audio fades** at the start AND end of every segment
   (Hard Rule 3). Without these, segment-concat produces audible pops.

4. **Cache check**: skip extraction if the output file exists AND its
   mtime is newer than both `edit/edl.json` and the source. The agent
   should never redo finished work.

5. After all ranges extracted, sanity check the count:
   ```bash
   /opt/claude-config/hooks/pipeline-gates.sh "<id>" cuts-extracted
   ```
   Must exit 0.

6. `manifest.stage = cuts-extracted`. Commit.

## Parallelism

This stage is embarrassingly parallel — one extract per range. Launch
N sub-agents (Agent tool, general-purpose) with one range each. Each
sub-agent's prompt includes the source path, range, grade filter, and
output index. Wall time ≈ slowest single extract.

If the agent budget is tight, batch into 4-worker groups instead of
fully parallel.

## Pitfalls

- **Single-pass filtergraph.** Tempting but wrong — it re-encodes the
  whole thing every time an overlay changes. Per-segment extract is
  non-negotiable (Hard Rule 2).
- **Grade applied post-concat.** Re-encodes twice. Wrong.
- **Forgetting fades.** First sign: pops at every cut on playback.
- **Hardware codec quality.** NVENC at default CQ produces visible
  banding on some content. Use `-cq 18` (or `-cq 23` for preview);
  validate with timeline-view if grading is critical.
- **Audio sample rate mismatch** between sources. The concat will
  refuse if rates differ. Normalize during extract: `-ar 48000`.

## Advance to: overlays-applied

Or, if `manifest.overlays` is empty, skip directly to
`audio-finalized` — the loop will route accordingly.
