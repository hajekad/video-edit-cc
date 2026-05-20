# Stage: audio-finalized

Build the output-timeline subtitle track, normalize loudness, and lock
the audio chain before render.

## Entry condition

- `manifest.stage == overlays-applied` (or `cuts-extracted` if no overlays)

## What to do

### 1. Build master.srt with output-timeline offsets (Hard Rule 5)

For each word in the WhisperX transcript that falls inside a kept
range, compute:

```
output_time = word.start - range.start + range_offset_in_output
```

where `range_offset_in_output` is the sum of preceding range
durations in the EDL. Write the SRT to `edit/master.srt`.

Source-time offsets are WRONG. The renderer expects output-time.

### 2. Apply subtitle style

Read `manifest.subtitles.style`. Default = `bold-overlay`:

```
FontName=Helvetica,FontSize=18,Bold=1,
PrimaryColour=&H00FFFFFF,OutlineColour=&H00000000,BackColour=&H00000000,
BorderStyle=1,Outline=2,Shadow=0,
Alignment=2,MarginV=35
```

Chunk into 2-word UPPERCASE segments by default. For narrative content,
switch to 4-7 word sentence case with `MarginV=60-80`.

Style is passed to ffmpeg via `force_style=` on the `subtitles` filter
when rendering. Subtitle styling lives in the renderer call, NOT in
the SRT file itself.

### 3. Audio normalize (loudnorm)

Run two-pass EBU R128 loudnorm via
`agents/Claude-Video-Editor-Plugin/skills/normalize-audio/`. Target:
- YouTube: -14 LUFS, -1 dBTP
- Broadcast: -23 LUFS, -1 dBTP
- Podcast: -16 LUFS, -1 dBTP

Read target from `manifest.audio.target` or default to -14 LUFS.

Apply to the EXTRACTED clips (per-segment) so the master concat is
already normalized.

### 4. Optional voiceover

If the strategy calls for a generated voiceover and `manifest.voiceover`
is populated:
- Generate via local TTS (F5-TTS or XTTS v2). Install via
  `agent-install` if not present.
- Save to `edit/voiceover/<n>.mp3` per scene.
- Reference in the EDL `overlays[]` for compositing during render.

### 5. Optional music bed

For music: source from royalty-free local libraries only — never paid.
Apply sidechain ducking (-12 dB under speech). Match BPM to pacing if
possible.

For MVP, music bed is **opt-in** via `manifest.music`. Default = none.

## Gate

```bash
/opt/claude-config/hooks/pipeline-gates.sh "<id>" audio-finalized
```

Must exit 0. `master.srt` must exist.

## `manifest.stage = audio-finalized`. Commit.

## Pitfalls

- **Source-time offsets in SRT.** Captions drift after segment concat.
  ALWAYS output-time (Hard Rule 5).
- **Subtitle text overlap with overlays.** Verify in self-eval stage.
  Subtitles render LAST in the filter chain (Hard Rule 1) but if
  `MarginV` puts them where an overlay sits, they collide.
- **Loudnorm in single pass.** Single-pass loudnorm is approximate;
  always two-pass for delivery.
- **TTS sample rate mismatch.** Generate at 48kHz to match video audio.
- **Music too loud.** -12 dB sidechain duck under speech is the floor;
  -18 dB is often better. Test with self-eval timeline_view + waveform.

## Advance to: rendered
