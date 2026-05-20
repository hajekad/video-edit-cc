---
description: Run self-eval on the current project's rendered output.
argument-hint: <project-name>
---

# /eval — self-eval at every cut boundary

Run timeline_view on the *rendered output* at every cut boundary (±1.5s
window) and check for visual jumps, audio pops, hidden subtitles,
mis-aligned overlays. Cap at 3 fix iterations.

## What to do

1. **cd** `/work/$1/`. Verify `manifest.stage` is at least `rendered`.

2. **Locate** the rendered output. Prefer `edit/preview.mp4` over
   `edit/final.mp4` for self-eval (faster to re-render fixes).

3. **For every range** in `edit/edl.json`, compute the output-timeline
   timestamp at the boundary (sum of preceding range durations) and
   run:
   ```bash
   python /agents/video-use/helpers/timeline_view.py \
       /work/$1/edit/preview.mp4 \
       <boundary_t - 1.5> <boundary_t + 1.5> \
       --out /work/$1/edit/verify/cut_<idx>.png
   ```

4. **Check each PNG + the surrounding waveform** for:
   - Visual discontinuity / flash / jump at the cut
   - Waveform spike at the boundary (audio pop slipping past 30ms fade)
   - Subtitle hidden behind an overlay (Hard Rule 1 violation)
   - Overlay misaligned or showing wrong frames (Hard Rule 4 violation)

5. **Also sample**: first 2s, last 2s, 2-3 mid-points. Check grade
   consistency, subtitle readability, overall coherence.

6. **ffprobe** the output to verify duration matches EDL expectation
   (within 5% or 2s, whichever is larger):
   ```bash
   /opt/claude-config/hooks/pipeline-gates.sh "$1" rendered
   ```

7. **On pass**: write `/work/$1/.claude/state/self-eval.verdict`:
   ```
   PASS
   <RFC3339 UTC timestamp>
   <one-sentence reason>
   ```
   Update `manifest.stage = self-eval-passed`.

8. **On fail**:
   - Document each failure in a `Bug` issue at `docs/issues/<n>-<slug>.md`
   - Fix the issue (re-extract segment, re-render overlay, etc.)
   - Re-render and re-eval
   - **Cap at 3 iterations.** After 3, write a FAIL verdict listing the
     unresolved gaps and flag to the user.
