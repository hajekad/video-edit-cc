# Stage: overlays-applied

If the strategy calls for animations (lower thirds, kinetic typography,
data viz, motion graphics, math diagrams), build them in parallel
sub-agents and composite them onto the extracts.

## Entry condition

- `manifest.stage == cuts-extracted`
- `manifest.overlays` is a non-empty array

(If `overlays` is empty, the loop skips straight to `audio-finalized`.)

## What to do

**One sub-agent per overlay slot.** Spawn N Agents in a single
message (parallel). Each gets a self-contained prompt with:

1. Goal: "Build ONE overlay: `<spec>`. Nothing else."
2. Output path: `/work/<id>/edit/animations/slot_<n>/render.mp4`
   (or `.webm` if alpha required)
3. Technical spec:
   - Resolution: matches `manifest.output_spec.width × height`
   - FPS: matches `manifest.output_spec.fps`
   - Codec: H.264 (or VP9 + alpha for transparency)
   - pix_fmt: `yuv420p` (or `yuva420p` for alpha)
   - Duration: from the overlay spec
4. Palette: concrete RGB tuples or hex from `manifest.brand` (NOT
   "brand colors" without resolution)
5. Font path with index (e.g., `/usr/share/fonts/.../font.ttc:1`)
6. Frame-by-frame timeline with easing per element
7. Engine — pick per slot, do not default:
   - **HyperFrames** (`/agents/hyperframes/`) for HTML/CSS/GSAP. Use
     `npx --yes hyperframes init . --example blank --non-interactive
     --skip-skills` then `hyperframes render . -o render.mp4`.
   - **Remotion** (`/agents/remotion-official-skills/`) for React
     compositions. Scaffold with `npx create-video@latest` in the slot.
   - **Manim** (`/agents/Math-To-Manim/`) for math / formal diagrams.
   - **PIL + ffmpeg** for simple cards (counters, typewriter text).
     Fastest iteration; the launch video in `video-use` used this.
8. Anti-list: no chrome, no titles unless specified, no auto-watermark.
9. Verification: ffprobe the render. Duration matches spec ± 0.05s.
   Dimensions exact. Pix_fmt exact.
10. "Do not ask questions. Pick the most defensible interpretation."

**Composite via `agents/video-use/helpers/render.py` overlay logic.**
It applies `setpts=PTS-STARTPTS+T/TB` so the overlay's frame 0 lands
at its window start (Hard Rule 4). Hand-rolling the composite is
forbidden — easy to get the PTS shift wrong.

After all slots render AND composite passes:
- Run `/opt/claude-config/hooks/pipeline-gates.sh <id> overlays-applied`
- `manifest.stage = overlays-applied`
- Commit

## Pitfalls

- **Sequential sub-agents.** Slow. Always parallel — single message,
  N tool calls (Hard Rule 10).
- **One sub-agent writing to multiple slot dirs.** Race condition.
  One slot per sub-agent.
- **Wrong pix_fmt** breaks composite. `yuv420p` for opaque, `yuva420p`
  for transparent. Verify with ffprobe.
- **Brand palette as "default."** If `manifest.brand` is empty, propose
  one and confirm with the user — do not invent.
- **Linear easing.** Hardly any motion graphics should use linear
  curves. `ease_out_cubic` for single reveals, `ease_in_out_cubic` for
  continuous draws.
- **Animation duration < narration_length + 1s** for over-VO overlays.
  Universal rule.
- **Parallel-reveal of independent elements.** Eye can't track two new
  things at once. One thing, pause, next thing.

## Advance to: audio-finalized
