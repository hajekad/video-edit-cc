---
name: fsh-broadcast-vocal-chain
description: Six-stage dialogue/voice mastering chain — DeepFilterNet noise reduction → LSP sidechain comp → LSP de-esser → LSP parametric EQ → ZAM brickwall limiter → ffmpeg loudnorm two-pass. Produces broadcast-grade vocal audio (-23 LUFS broadcast, -14 LUFS YouTube, -27 LUFS cinema). Use in the audio-finalized stage on any project with dialogue or voiceover. Replaces the "I'll just run loudnorm" reflex with a real mastering chain.
version: 1.0.0
---

# Broadcast Vocal Chain — DIY Mastering for Dialogue

The research surveyed every public OSS dialogue-mastering skill repo.
**No prebuilt "broadcast vocal chain" repo exists.** Commercial tools
(iZotope RX, Acon DeNoise, Nugen ISL) own this space. This file is the
FotoStudioH-native chain that approximates broadcast standards using
only locally-installable OSS tools.

## When to invoke

Triggered in the **audio-finalized** pipeline stage on any project
where:
- `manifest.inputs[i].audio_channels > 0` (project has audio)
- The audio carries speech (interview, vlog, tutorial, narration,
  documentary, etc.) — not music-only material
- `manifest.audio.target` is set (or default to -14 LUFS YouTube if
  not)

Skip for:
- Music-only deliverables (use `fsh-music-mood-bridge/SKILL.md`
  mastering chain instead — different bar)
- Material already mastered by an external engineer
- Quick-preview renders (the chain costs ~30s per minute of audio)

## The chain (six stages, in order)

Apply per-segment during cuts-extracted stage. The chain produces a
new audio track that replaces the original; preserve the original at
`edit/clips_graded/<idx>.audio_backup.wav` for rollback.

### Stage 1 — Noise floor reduction (DeepFilterNet 3)

```bash
# Decode source audio to a temp WAV (DFN3 wants WAV input)
ffmpeg -i edit/clips_graded/01.mp4 -vn -acodec pcm_s24le -ar 48000 /tmp/01.raw.wav

# DFN3 denoise — gentle setting; aggressive setting kills whispers
/opt/ml-venv/bin/python -m df.enhance \
    --model DeepFilterNet3 \
    --no-delay-compensation \
    /tmp/01.raw.wav /tmp/01.dfn.wav
```

**Tuning**: DFN3 default is aggressive on whispers and breaths. If the
content is intimate (interview, ASMR, low-energy narration), pre-
process with rnnoise instead and skip DFN3. Detect intimacy by reading
the RMS energy curve from the WhisperX transcript — if average RMS is
below -25 dBFS, skip DFN3.

**Skip entirely** if the source is already studio-clean (RMS noise floor
below -55 dBFS as measured by `pyloudnorm` or `ffmpeg ebur128`).

### Stage 2 — Sidechain compression (LSP `sc_compressor_mono`)

Gentle 2:1 ratio at -18 dB threshold with sidechain HPF at 80 Hz.
Reduces dialogue dynamic range without pumping artifacts.

```bash
ffmpeg -i /tmp/01.dfn.wav \
    -af "lv2=lsp-plugins.lv2/sc_compressor_mono:c=ratio=2:c=threshold=-18:c=knee=6:c=attack=10:c=release=80:c=sidechain_hpf_freq=80" \
    /tmp/01.comp.wav
```

**Why sidechain HPF**: prevents the compressor from "pumping" on
low-frequency rumble or plosives. The compressor only listens to the
speech band (80 Hz and up).

### Stage 3 — De-essing (LSP `mb_compressor_mono` as de-esser)

Reduce harsh sibilance in the 5-8 kHz band only.

```bash
ffmpeg -i /tmp/01.comp.wav \
    -af "lv2=lsp-plugins.lv2/mb_compressor_mono:c=mode=multiband:c=band5_ratio=4:c=band5_threshold=-20:c=band5_attack=0.5:c=band5_release=50" \
    /tmp/01.dees.wav
```

**Skip** if the speaker doesn't have sibilance issues (most don't —
check by listening to /tmp/01.comp.wav first or by sampling 0.5s
windows around any "s"/"sh"/"f" in the WhisperX transcript).

### Stage 4 — Tonal EQ (LSP `para_equalizer_x16_mono`)

Three corrective bands:
- HPF at 80 Hz (rumble removal)
- Notch at any room mode the speaker hits (often 200-300 Hz)
- Presence boost at 3-5 kHz (+2 to +4 dB, gentle Q)

```bash
ffmpeg -i /tmp/01.dees.wav \
    -af "lv2=lsp-plugins.lv2/para_equalizer_x16_mono:c=f1=80:c=g1=-20:c=q1=0.7:c=t1=hpf:c=f2=200:c=g2=-3:c=q2=2:c=t2=peak:c=f3=4000:c=g3=3:c=q3=0.7:c=t3=peak" \
    /tmp/01.eq.wav
```

**Note**: LSP plugin URIs above are illustrative — exact LV2 URI strings
vary by LSP version. Check with `lv2ls | grep lsp-plugins` after install.
Use the `controls=...` syntax that ffmpeg's `lv2` filter accepts.

### Stage 5 — Brickwall limiter (ZAM `ZaMaximX2`)

Output ceiling depending on delivery target:
- Cinema / theatrical: -2 dBTP
- Streaming (YouTube, Vimeo): -1 dBTP
- Broadcast (EBU R128): -1 dBTP

```bash
ffmpeg -i /tmp/01.eq.wav \
    -af "lv2=ZamMaximX2:c=output_ceiling=-1:c=lookahead=10" \
    /tmp/01.lim.wav
```

### Stage 6 — Two-pass loudnorm (ffmpeg)

Target LUFS depends on delivery:
- Cinema (theatrical print master): -27 LUFS (dialnorm)
- Broadcast (EBU R128): -23 LUFS
- YouTube / streaming video: -14 LUFS
- TikTok / Reels: -9 LUFS (de facto, optional)
- Podcast: -16 LUFS

```bash
# Pass 1: measure
ffmpeg -i /tmp/01.lim.wav -af "loudnorm=I=-14:LRA=11:tp=-1:print_format=json" -f null - 2> /tmp/01.loudness.json

# Pass 2: apply with measured values
ffmpeg -i /tmp/01.lim.wav \
    -af "loudnorm=I=-14:LRA=11:tp=-1:measured_I=<from json>:measured_LRA=<from json>:measured_tp=<from json>:measured_thresh=<from json>:offset=<from json>:linear=true" \
    -c:a pcm_s24le /tmp/01.final.wav
```

### Re-mux into the segment

Replace the segment's audio without re-encoding video:

```bash
ffmpeg -i edit/clips_graded/01.mp4 -i /tmp/01.final.wav \
    -map 0:v -map 1:a \
    -c:v copy -c:a aac -b:a 256k \
    edit/clips_graded/01.mastered.mp4 && \
    mv edit/clips_graded/01.mp4 edit/clips_graded/01.audio_backup.mp4 && \
    mv edit/clips_graded/01.mastered.mp4 edit/clips_graded/01.mp4
```

## LUFS targets per delivery (quick reference)

| Delivery | Integrated LUFS | True peak | Dynamic range (LRA) |
|---|---:|---:|---:|
| **IMAX / DCP theatrical** | dialnorm -27 LKFS | -2 dBTP | ≥20 LU |
| Trailers (theatrical) | -- | -- | LEQ(m) ≤ 85 dB |
| Commercials (theatrical) | -- | -- | LEQ(m) ≤ 82 dB |
| Broadcast (EBU R128) | -23 LUFS ±0.5 | -1 dBTP | LRA 10-15 LU |
| Netflix streaming | -27 LKFS | -2 dBTP | LRA 4-18 |
| YouTube / Vimeo | -14 LUFS | -1 dBTP | LRA 6-10 |
| Apple Music / Tidal | -16 LUFS | -1 dBTP | LRA 5-8 |
| Podcast | -16 LUFS | -1 dBTP | LRA 6-12 |
| TikTok / Reels (de facto) | -9 LUFS | -1 dBTP | LRA 4-6 |

**CRITICAL**: Cinema-bound output requires dynamic range preservation.
Aggressive loudnorm + limiting destroys LRA. For IMAX work, SKIP
stages 5-6 of this chain entirely; deliver at the post-Stage-4 level
and let the cinema mastering house apply theatrical limiting.

## Verification

After the chain runs, verify with `pyloudnorm`:

```bash
/opt/ml-venv/bin/python << 'EOF'
import pyloudnorm as pyln
import soundfile as sf
data, rate = sf.read('/tmp/01.final.wav')
meter = pyln.Meter(rate)
print(f"Integrated: {meter.integrated_loudness(data):.2f} LUFS")
EOF
```

The measured value MUST be within ±0.5 LUFS of target. If not, adjust
the `loudnorm` `I=` parameter and re-run pass 2.

## What this chain CANNOT do

- **Spectral repair** (mouth clicks, breath edits, single problem
  spectro-temporal blobs) — needs iZotope RX or hand work
- **De-reverb** at production quality — research models exist, no OSS
  production tool
- **Convincing voice "warmth"** — that's tape saturation, tube emulation,
  analog character. OSS approximations exist (ZAM ZamTube) but limited
- **Mouth-noise removal** (smacks, swallows) — needs RX or hand-editing

For these, **flag honestly** to the user that broadcast-grade vocal
mastering needs human intervention or a paid pass. Don't fake it.

## Cross-references

- Hard Rule 3 (30ms fades): `agents/CLAUDE.md`. Apply BEFORE this chain.
- Music mastering (different bar): `agents/fsh-music-mood-bridge/`,
  `agents/fsh-royalty-free-music/`
- Cinema/IMAX honest gaps: `docs/research/08-cinema-imax-mastering.md`
- LSP plugins documentation: https://lsp-plug.in/ (installed via
  `agent-install lsp-plugins-lv2`)
- DFN3: `agent-install python-deepfilternet` or pip install in /opt/ml-venv
