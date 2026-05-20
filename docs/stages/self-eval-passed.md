# Stage: self-eval-passed

Run `timeline_view` at every cut boundary on the rendered output.
Check for visual jumps, audio pops, hidden subtitles, mis-aligned
overlays. Cap at 3 fix iterations.

## Entry condition

- `manifest.stage == rendered`
- `edit/preview.mp4` exists

## What to do

### For every cut boundary in the EDL

Compute the boundary time on the OUTPUT timeline (cumulative sum of
preceding range durations). For each, run:

```bash
/opt/claude-config/tools/cut-boundary /work/<id>/edit/preview.mp4 <t>
```

This produces a PNG (filmstrip + waveform + word labels) for the
±1.5s window around the cut. Read it as an image and check:

1. **Visual continuity** — no flash, no jump, no smash unless the
   strategy specified one
2. **Waveform smoothness** — no spike at the boundary (Hard Rule 3
   violation = audible pop)
3. **Subtitle visibility** — every spoken word in the window has a
   matching subtitle line on screen (or the gap was deliberate)
4. **Overlay alignment** — if an overlay's window crosses this cut,
   the overlay shows the correct frame (not the middle of the
   animation — that's a PTS-shift bug, Hard Rule 4)

### Also sample non-cut points

- **First 2s**: hook works, grade looks right, no flash on start
- **Last 2s**: outro lands, no truncation
- **2-3 mid-points**: grade consistent, subtitle readable, overall coherence

### ffprobe duration check

```bash
/opt/claude-config/tools/ffprobe-json /work/<id>/edit/preview.mp4
```

Compare to `edl.total_duration_s`. Must match within tolerance.

### Verdict

If everything passes, write `/work/<id>/.claude/state/self-eval.verdict`:

```
PASS
<RFC 3339 UTC timestamp>
<one-sentence reason citing the boundaries checked>
```

If anything fails:
1. File ONE `Bug` issue per failure under `/work/<id>/docs/issues/`.
   Include the offending boundary timestamp, the specific check that
   failed, and a proposed fix.
2. Fix the issue (re-extract a segment, re-render an overlay, etc.).
3. Re-render preview.
4. Re-eval.

**Cap at 3 iterations.** After the 3rd failed pass, write:

```
FAIL
<RFC 3339 UTC timestamp>
<list of unresolved gaps with boundary timestamps>
```

Then flag to the user. Do NOT advance to `delivered` from a FAIL
verdict.

## Gate

```bash
/opt/claude-config/hooks/pipeline-gates.sh "<id>" self-eval-passed
```

Reads `self-eval.verdict` first line. Must be `PASS` or `APPROVED`.

## `manifest.stage = self-eval-passed`. Commit.

## Pitfalls

- **"Looks good to me" without timeline-view.** That's not self-eval.
  Read the actual PNG.
- **Skipping mid-point samples.** A cut might look fine in isolation
  but break grade consistency across the timeline.
- **Re-rendering on every cut failure.** Batch fixes: gather all
  failures, fix all, re-render once, re-eval once. Each render is 1-2
  minutes; iteration cap is on the eval cycles, not the cut fixes.
- **FAIL declared as PASS.** The reviewer sub-agent (issue-state-review)
  catches this when advancing `delivered`, but don't lie to yourself.
- **3-iteration cap ignored.** If the 3rd pass still fails, STOP and
  flag. Looping more wastes GPU time and rarely converges.

## Advance to: delivered
