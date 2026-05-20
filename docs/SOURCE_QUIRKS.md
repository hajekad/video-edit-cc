# Source Quirks Catalog

Per-camera / per-codec / per-workflow patterns that re-emerge across
projects and that the agent must NOT re-discover from scratch. Living
catalog — add a quirk the first time it costs an edit, and every
future agent reads from this file during `/inventory`.

> Reference cases:
> - Smoke #1 figured out "Sony VVHA*.MP4 = vertically composed, stored
>   landscape, no rotation metadata, needs `transpose=2`." Smoke #2
>   re-encountered the same footage and flipped the hypothesis the
>   WRONG way (assumed it was truly landscape), shipped a cut with
>   center-cropped wrong-composition framing on every Sony shot.
> - The fix isn't "be smarter next time." It's this file + the
>   `orientation-check` tool that forces a both-orientations
>   comparison before commitment.

## How to use this catalog

During `/inventory`'s ffprobe pass, the agent matches each source
against the patterns below by (a) camera make/model from EXIF/metadata,
(b) codec + container, (c) filename signature, (d) a visual probe via
`orientation-check`. When a match fires, the agent records the
**inferred quirk + the WHY** in `manifest.inputs[].quirks[]` BEFORE
committing to a render strategy.

Format:

```json
"inputs": [
  {
    "file": "VVHA9412.MP4",
    "width": 3840,
    "height": 2160,
    "quirks": [
      {
        "id": "sony-vertical-composed-stored-landscape",
        "fix": "apply transpose=2 before scale",
        "evidence": "edit/orient_check/VVHA9412_orientations.jpg",
        "confirmed_by": "visual-comparison"
      }
    ]
  }
]
```

## Quirk: `sony-vertical-composed-stored-landscape`

**Cameras:** Sony A7-class, A7S, A7 IV, FX3, ZV-E1 with vertical-grip
or hand-held portrait composition.

**Signature:**
- Filename pattern: `VVHA*.MP4`, `C0*.MP4`, `A7*.MP4`
- ffprobe shows `width=3840 height=2160` with **NO** `rotation`
  side_data and **NO** `tags.rotate`
- Visual: thumbnails read sideways in any standard image viewer; tank
  cylinders run horizontal, subjects' heads pointing left/right;
  rotating the thumbnail 90° CCW makes the composition snap to
  natural portrait

**Fix:** apply `transpose=2` (90° CCW) BEFORE scale/crop in every
ffmpeg pass. iPhone clips in the same project may carry their own
rotation metadata and need no transpose — verify per-source.

**How to confirm in 30s:** run
`/opt/claude-config/tools/orientation-check <source.mp4>`. The tool
extracts side-by-side `as_stored` and `transpose=2` thumbnails. The
correct orientation is the one where subjects stand upright, horizons
are horizontal, and text is readable.

**Why this re-emerges:** Sony cameras don't always write rotation flags
even when the operator composes portrait — particularly in pro
workflows where the operator might intend to grade in landscape and
reframe later. The "raw landscape, intended portrait" pattern is
common in social-first commercial shoots.

## Quirk: `iphone-rotation-metadata-respected`

**Cameras:** iPhone 12+ / Pro / Pro Max in portrait

**Signature:**
- Filename pattern: `IMG_*.MOV`
- ffprobe shows `width=1920 height=1080` (or larger) WITH `rotation
  side_data: rotate=-90` or `tags.rotate=90`
- Thumbnail viewers honour the rotation metadata; the frame reads
  portrait correctly without any transpose

**Fix:** no transpose needed. Treat `display_width × display_height` as
the working frame. ffmpeg `autorotate` (default in recent builds)
handles it.

**Trap:** mixing iPhone IMG_*.MOV with Sony VVHA*.MP4 in the same
project tempts the agent to pick a single orientation strategy. WRONG.
Each source needs its own quirk match.

## Quirk: `gopro-anamorphic-squeezed`

**Cameras:** GoPro Hero 9+ in 4:3 SuperView / 8:7 modes

**Signature:**
- Filename pattern: `GH010*.MP4`, `GX01*.MP4`
- ffprobe shows non-square sample aspect ratio
  (`display_aspect_ratio != width/height`)

**Fix:** apply the SAR-to-DAR scale step (`-vf scale=iw*sar:ih`)
BEFORE any crop. Otherwise output looks squeezed.

**How to confirm:** `ffprobe -select_streams v:0 -show_entries
stream=display_aspect_ratio,sample_aspect_ratio,width,height`.

## Quirk: `dji-flat-log-needs-grade`

**Cameras:** DJI Mini 3 Pro, Air 3, Mavic 3 in D-Cinelike / D-Log M

**Signature:**
- Filename pattern: `DJI_*.MP4`
- ffprobe `color_space=bt709`, `color_transfer=arib-std-b67` (HLG) or
  `smpte2084` (PQ); flat-looking thumbnails with washed contrast

**Fix:** apply a corrective LUT or
`eq=contrast=1.15:saturation=1.20:gamma=0.95` minimum before delivery
encode. Otherwise the cut looks under-graded next to native bt709
sources.

## Quirk: `red-r3d-needs-resolve`

**Cameras:** RED Komodo, Helium, Monstro

**Signature:** `.R3D` extension

**Fix:** out of scope for FSH local pipeline — no R3D decoder ships
with ffmpeg-arch. File a `Capability` issue if .R3D lands in `raw/`.
Direct the user to transcode upstream in DaVinci Resolve / RedCine-X.

## Quirk: `multi-camera-mixed-fps`

**Pattern:** project has 50fps + 25fps + 30fps + 24fps sources mixed.

**Signature:** ffprobe across `raw/` shows ≥3 distinct frame rates.

**Fix:** normalize ALL sources to delivery fps (`fps=30` for Reels;
`fps=24` or `fps=25` for broadcast) during per-segment extract. NEVER
post-concat — that produces irregular frame timing. Hard Rule 2 (lossless
concat) requires uniform fps.

## Quirk: `audio-at-different-sample-rates`

**Pattern:** mixed 44.1kHz / 48kHz / 96kHz across `raw/`.

**Fix:** normalize ALL audio to 48kHz stereo during per-segment
extract (`-ar 48000 -ac 2`). Mismatches break concat or produce
silent segments after concat.

## Quirk: `czech-or-other-diacritics-in-subtitles`

**Pattern:** burned subtitles include Czech / Polish / Slovak / Czech
characters (`á č ď é ě í ň ó ř š ť ú ů ý ž`).

**Signature:** transcript language detected as non-English; brief
mentions a Czech / Slovak / Polish region.

**Fix:** use `drawtext` with `textfile=` reading UTF-8 from a file (NOT
inline `text=` which mangles via shell escaping). Pick a font with the
full Latin-Extended-A glyph set — Liberation Sans, DejaVu Sans, Noto
Sans all work. Avoid Arial / Helvetica unless verified.

**Trap:** ASS `subtitles` filter sometimes ignores PlayResY scaling at
non-standard output dimensions (1080×1920 vertical, in particular) —
caption renders at ~40% of frame height. drawtext is the safer path
since the smoke test catch.

## Quirk: `branded-third-party-logo-in-frame`

**Pattern:** raw footage incidentally captures a third-party brand
(Wascosa, WGT, Honeywell, supplier logos on PPE, hazmat plates) that
the deliverable's client doesn't have a co-marketing agreement for.

**Signature:** during the `/inventory` thumbnail review pass, the
agent visually identifies non-client branding in frame.

**Fix:** flag the affected source in `manifest.inputs[].quirks[]` as
`third-party-brand-in-frame`. Prefer to swap to a clean equivalent
during EDL build (smoke #2 swapped seg03 from VVHA9465 to VVHA9419).
If swap isn't possible, mask via:
- vertical pillar-box / drawtext block at the offending region
- chroma-keying the branded element out (rare; risky)
- noting it in the delivery README so brand team can vet on receipt

**Why:** ESG / corporate deliverables fail brand-team review when a
competing or unrelated brand appears with the client's mark on the
close card. Smoke #2's WGT save was good editorial — the catalog
prevents it from depending on agent vigilance alone.

## Quirk: `single-camera-multitake-drift`

**Pattern:** static-cam interview / talking-head where 5-15 takes were
recorded in one continuous file, separated by re-frames.

**Signature:** one source much longer than the rest (10+ min); WhisperX
shows repeated identical phrases at different timestamps.

**Fix:** PySceneDetect to auto-segment by visual cuts; align with
transcript repeats to identify best-take per phrase. Don't ship the
whole take.

## Adding a new quirk

When you encounter a re-emerging pattern that costs an edit (or almost
did), append a new section here with:
- Camera / codec / context
- Signature (how to detect it programmatically + visually)
- Fix (one-line ffmpeg recipe or workflow)
- How to confirm in 30s
- Optional: why it re-emerges, traps to avoid

This file lives at `/docs/SOURCE_QUIRKS.md` and is referenced by:
- `/opt/claude-config/commands/inventory.md` — required reading at
  inventory time
- `/opt/claude-config/tools/orientation-check` — first cousin tool
- `/docs/BRIEF_INTERPRETATION.md` § Signal read — quirks are signals
