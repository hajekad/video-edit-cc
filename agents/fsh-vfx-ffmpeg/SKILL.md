---
name: fsh-vfx-ffmpeg
description: VFX patterns achievable with ffmpeg + SAM2 + ImageMagick + PIL — no After Effects / Nuke required. Chroma key (greenscreen), light wrap, lens flares, particle overlays, image-composite VFX, SAM2-driven masks. Use when the strategy calls for visual effects beyond Hyperframes/Remotion overlays — actual compositing of real footage with effects layers.
version: 1.0.0
---

# VFX Patterns — ffmpeg + SAM2

The research surveyed every public OSS VFX skill repo. **None exists at
production quality.** Commercial tools (Nuke, After Effects) own this
space. But ffmpeg + SAM2 + ImageMagick cover 80% of the VFX patterns
FotoStudioH will actually need.

## When to reach for this skill vs alternatives

| If the task is | Reach for |
|---|---|
| Cleanup / mask removal / object remove | `Sanster/IOPaint` (LaMa, ZITS) — separate runtime |
| Background removal from still | `danielgatis/rembg` (rembg CLI) |
| Image relighting | `lllyasviel/IC-Light` (diffusion-based) |
| Video stem separation (audio) | `facebookresearch/demucs` |
| Code-rendered overlays | `agents/hyperframes/` or `agents/remotion-official-skills/` |
| Math / data viz overlays | `agents/Math-To-Manim/` |
| **Chroma key, light wrap, particle overlay, image-composite VFX** | **This skill** |
| Multi-track timeline VFX | Hand off to Resolve / Premiere via `buttercut` NLE export |

## Chroma key (greenscreen)

ffmpeg has two filters: `colorkey` (full transparency) and `chromakey`
(transparency + blend). Prefer `chromakey` — `colorkey` produces edge
fringing.

```bash
# Single layer green-screen → transparent over background
ffmpeg -i background.mp4 -i greenscreen.mp4 \
    -filter_complex "[1:v]chromakey=0x00b140:0.18:0.07[ckout];[0:v][ckout]overlay" \
    -c:v h264_nvenc -cq 18 -pix_fmt yuv420p output.mp4
```

Key parameters:
- `0x00b140` = the color to key out (greenscreen green). Adjust per shoot.
- `0.18` = similarity (0.0 = exact match only, higher = looser match)
- `0.07` = blend (transition from keyed to not-keyed; higher = softer edge)

**Quality knobs**:
- Always shoot the green at f/2.8-f/5.6 (no DOF over the background)
- Light the green flat — gradient lighting kills the key
- For finer keys, pre-process with `despill` (a separate ImageMagick or
  ffmpeg expr filter) to suppress green color cast on subject's edges

## Light wrap (post-key edge softening)

After keying, the subject often has hard, unnatural edges. Light wrap
samples the new background and blurs a thin halo of it ONTO the
subject's edges, making the comp look photographed-in-place.

```bash
# Light wrap via ffmpeg blend filter
ffmpeg -i keyed_subject.mov -i background.mp4 \
    -filter_complex "
        [1:v]boxblur=20[bg_blur];
        [0:v][bg_blur]blend=all_mode=screen:enable='lt(N,inf)':all_opacity=0.15[wrap];
        [0:v][wrap]overlay=format=auto
    " \
    -c:v h264_nvenc output.mp4
```

The `boxblur=20` + `screen` blend at 15% opacity is the standard
recipe. Tune blur radius to match the focal length of the original
shot (shallow DOF needs more blur).

## Lens flare overlay

Don't generate lens flare procedurally — composite a stock flare PNG
or pre-rendered MP4 with `screen` blend mode.

```bash
# Composite a flare PNG sequence (or MP4) on top
ffmpeg -i base.mp4 -i flare_sequence_%04d.png \
    -filter_complex "[1:v]format=rgba,scale=1920:1080[flare];[0:v][flare]blend=all_mode=screen:all_opacity=0.7" \
    -c:v h264_nvenc output.mp4
```

For lens flare assets: use royalty-free stock packs (e.g., from
Pixabay), or generate via diffusers with a transparent background and
chroma key the dark.

## Particle overlays (dust, sparks, snow, smoke)

Same pattern as lens flare — composite a stock particle MP4 with
`screen` (for light particles) or `multiply` (for dark particles) blend.

```bash
# Sparks/dust (light particles → screen blend)
ffmpeg -i base.mp4 -i sparks.mp4 \
    -filter_complex "[0:v][1:v]blend=all_mode=screen:all_opacity=0.6" \
    -c:v h264_nvenc output.mp4

# Smoke / mist (dark or neutral particles → multiply or overlay)
ffmpeg -i base.mp4 -i smoke.mp4 \
    -filter_complex "[0:v][1:v]blend=all_mode=multiply:all_opacity=0.5" \
    -c:v h264_nvenc output.mp4
```

## SAM2-driven masks (roto without manual roto)

For shots without a clean green-screen, segment the subject with SAM2
(Segment Anything 2) and use the mask as the alpha channel.

```bash
# Step 1: Extract per-frame masks via SAM2 (separate Python call)
/opt/ml-venv/bin/python << 'EOF'
from sam2.sam2_video_predictor import SAM2VideoPredictor
import os
predictor = SAM2VideoPredictor.from_pretrained("facebook/sam2.1-hiera-large")
# Click on the subject in frame 0 — propagated through the video
# Outputs PNG mask sequence to /tmp/sam2_masks/
# See `agents/facebookresearch/sam2/notebooks/video_predictor_example.ipynb`
EOF

# Step 2: Composite the masked subject onto a new background
ffmpeg -i original.mp4 -i /tmp/sam2_masks/%05d.png -i background.mp4 \
    -filter_complex "
        [1:v]scale=1920:1080,format=gray[mask];
        [0:v][mask]alphamerge[fg];
        [2:v][fg]overlay
    " \
    -c:v h264_nvenc -pix_fmt yuv420p output.mp4
```

**SAM2 caveat**: this is roto-at-AI-quality, not VFX-house quality.
Hair edges and motion blur cause issues. For final-quality theatrical
work, hand off to a human roto artist. For social/marketing pieces,
SAM2 is good enough.

## Image-composite VFX with ImageMagick

For complex still composites (matte paintings, set extensions, text
treatments) use ImageMagick. The `-composite` operator handles
foreground-over-background with alpha:

```bash
# Place subject (with alpha) over matte painting
magick matte_painting.jpg subject_with_alpha.png -composite -gravity center final.jpg
```

For per-frame composites where the foreground or background animates,
generate each frame and pipe through ffmpeg:

```bash
# Pseudo: per-frame composite, then encode to MP4
mkdir /tmp/comp
for i in $(seq -w 0001 0500); do
  magick "background_$i.jpg" "subject_$i.png" -composite "/tmp/comp/frame_$i.png"
done
ffmpeg -framerate 24 -i /tmp/comp/frame_%04d.png -c:v h264_nvenc -pix_fmt yuv420p output.mp4
```

## Sky replacement (limited OSS path)

The only OSS sky-replacement tool is `jiupinjia/SkyAR` (2K stars,
stale 2022). For modern sky replacement: combine SAM2 for the sky mask
+ a stock sky video composited via `chromakey`-style replacement.

Honest limit: AI-quality sky replacement (matching color cast +
lighting direction across the subject) requires commercial tools or
hand-grading. For documentary / brand pieces where the sky just needs
to be REPLACED with something acceptable, SAM2 + composite works.

## What this skill CANNOT do (paid-tool territory)

- Frame-perfect roto (hair, fur, motion blur edges)
- AI-quality sky replacement with lighting transfer
- Particle simulation that interacts with subjects (only canned overlays)
- Volumetric / depth-aware VFX
- Multi-pass deep compositing (light passes, ambient occlusion, etc.)

For any of these, the agent should flag the user that this requires
NLE+VFX handoff. **Honest disclosure beats fake competence.**

## Hard Rule compliance

When applying VFX effects to per-segment extracts already in
`edit/clips_graded/`:

- Apply BEFORE the master concat (per Hard Rule 2: per-segment extract → lossless concat)
- Re-encode the affected segment(s) only, not the whole timeline
- If the segment has overlays attached, apply the VFX layer FIRST, then the overlay (subtitles always last per Hard Rule 1)
- Audio is unchanged by VFX work; keep the original audio track untouched
- If VFX work is destructive to a segment, save the pre-VFX version
  at `edit/clips_graded/<idx>.vfx_backup.mp4` so the segment can be
  rebuilt if VFX is rejected

## Cross-references

- Hard Rules 1-12: `agents/CLAUDE.md`
- Photo composition (still VFX evaluation): `agents/fsh-photo-composition/SKILL.md`
- Color grade (often the right answer instead of VFX): `agents/video-use/SKILL.md` § Color grade
- Hyperframes for code-rendered overlays: `agents/hyperframes/`
- Image generation backends: `docs/research/06-photo-vfx-3d.md`
