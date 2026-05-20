# Research: theatrical / cinema / IMAX-grade audio mastering

Background research output from a parallel agent. Deep dive on what's
achievable with OSS for cinema/IMAX-bound audio. Companion to report
07-music-workflow.md (which covered mastering at a high level).

## Honest upfront caveat

True IMAX/DCI delivery requires (a) proprietary codec licensing
(Dolby Atmos, DTS:X, IMAX Enhanced) that NO OSS chain can replicate,
(b) human mastering engineers calibrated to an 85 dB SPL room, and
(c) reference monitoring chains. OSS gets you to a clean stereo / 5.1
PCM submaster + DCI-compliant WAV stems suitable for handoff to a
commercial mastering house. **Treat the OSS chain as pre-mastering
and submaster delivery, not final theatrical encode.**

## Specs (verified)

- **DCP feature film dialogue**: -27 LKFS ±2 LU gated, BS.1770-3/4. Calibration is at 85 dB SPL pink noise at -20 dBFS RMS (SMPTE RP 200:2012). Reference fader = 0.
- **Theatrical trailer**: 85 dB Leq(m) (TASA). Commercial: 82 dB Leq(m) (SAWA).
- **IMAX-specific**: 12-channel immersive (7 base + 5 height, NO LFE in theater content) is proprietary. Theatrical IMAX mixes carry -27 LKFS dialogue + high dynamic range (LRA often 20+). For streaming/IMAX Enhanced, DTS:X downmixes to 5.1.4 with LFE.
- **Streaming (Netflix v1.6)**: -27 LKFS dialogue ±2 LU, true-peak ≤ -2 dBTP, LRA 4-18 for full mix, ≤10 for dialogue.

## Top 3 must-clones

1. **`ZFTurbo/Music-Source-Separation-Training`** (1.3K★, MIT) — SOTA Mel-Band/BS-RoFormer with pretrained weights. SDR vocals 10.87-11.99, beats Demucs by ~1.5 dB. ~9 GB VRAM at default chunk, fits 3080 Ti with tuning.

2. **`lsp-plugins/lsp-plugins`** (820★, LGPL-3) — The mastering chain backbone. Multiband compressor + dynamic EQ + limiter + parametric EQ. Headless via ffmpeg `-af lv2=`. Mathematically correct, sonically slightly clinical vs FabFilter — acceptable for the chain you can audit.

3. **`ebu/ebu_adm_renderer`** (98★, BSD-3-Clear) — Python ref impl of ITU-R BS.2127 ADM renderer. Reads ADM-BWF object-based audio, renders to ANY ITU-R BS.2051 layout (5.1, 7.1, 7.1.4, 9.1.6, 22.2). **Open Atmos equivalent for NGA delivery — not Dolby-compatible at bitstream level**, but produces theatrical-grade multichannel WAVs.

## Honorable mentions (sub-50★ but uniquely valuable)

- **`lucat/leqm-nrt`** (8★) — the ONLY OSS Leq(m) impl. Required for trailer/commercial compliance (85/82 dB Leq(m)).
- **`mikrosimage/loudness_validator`** (16★) — closest to OSS conformance auditor (EBU R128 + ATSC A/85 + CST RT-017).
- **`x42/dpl.lv2`** (23★) — Fons Adriaensen's trusted look-ahead true-peak limiter.

## Loudness tools

| Tool | License | Verdict |
|---|---|---|
| `csteinmetz1/pyloudnorm` (772★) | MIT | pip install — BS.1770-4 reference impl |
| `jiixyj/libebur128` (479★) | MIT | install via ffmpeg (already uses it) |
| ghedo/loudgain (use Moonbase59 fork ~250★) | BSD-2 | skip primary, use fork for music tagging only |
| `x42/meters.lv2` (221★) | GPL-2 | install for ebur128 visual meter; headless not great |

**Verification gap**: there is NO OSS equivalent of Nugen LM-Correct or BBC EBU R128 audit suite end-to-end. The four tools above + ffmpeg ebur128 form a stitched-together pipeline.

## Mastering chains

| Tool | License | Verdict |
|---|---|---|
| `lsp-plugins/lsp-plugins` (820★) | LGPL-3 | **install — the chain backbone** |
| `x42/dpl.lv2` (23★) | GPL-3 | install — trusted limiter |
| `zamaudio/zam-plugins` (308★) | GPL-2 | install — ZaMaximX2 brickwall, ZamMultiCompX2, ZamGEQ31, ZamTube |
| Calf plugins (410★) | LGPL | install only if LSP unavailable |
| `sergree/matchering` (2.5K★) | GPL-3 | **WARNING: matchering crushes dynamics to match a reference, killing LRA. Use ONLY for music cues at streaming loudness, NOT cinema print masters.** |

### AI mastering — local?
- matchering is the only credible local "AI-style" tool, but it's classical DSP not neural.
- True neural mastering (LANDR-style) — **NO open-weights model exists.** Real OSS gap.

## Multichannel / surround / Atmos

### Hard truth on Atmos
**No OSS path to a Dolby Atmos master.** Dolby Atmos Production Suite is the only legal path to ADM BWF for Atmos-licensed exhibition.

But EBU has built an open NGA chain that mimics Atmos's object model:

| Tool | License | Verdict |
|---|---|---|
| `ebu/ebu_adm_renderer` (98★) | BSD-3-Clear | **install — open Atmos equivalent for NGA** |
| `ebu/ear-production-suite` (121★) | GPL-3 | reference; Reaper-only VSTs |
| `ebu/libadm` (50★) | Apache-2 | link as lib for ADM I/O |
| `VoidXH/Cavern` (506★) | NOASSERTION (commercial-restrictive) | reference-only — license problem |
| `leomccormack/SPARTA` (741★) | GPL-3 | reference; JUCE plugins |
| `leomccormack/Spatial_Audio_Framework` (720★) | ISC+MIT dual (commercial OK) | **install — best OSS spatial audio engine** |
| `kronihias/ambix` (265★) | GPL-2 | install — variable-order ambix |
| resonance-audio (538★) | Apache-2 | skip — Google killed it |

### Stereo→5.1 upmix gap
**No OSS neural upmix exists.** Commercial tools (Penteo, Halo Upmix, dearVR) own this space. ffmpeg's `surround` filter is acceptable for non-creative dialogue/music spread; not theatrically convincing.

## Stem separation

| Tool | License | Verdict |
|---|---|---|
| **`ZFTurbo/Music-Source-Separation-Training`** (1.3K★) | MIT | **install — SOTA Roformer with pretrained weights** |
| `facebookresearch/demucs` (10.1K★) | MIT | install — htdemucs_ft, ~6 GB VRAM, 2-4× realtime |
| `lucidrains/BS-RoFormer` (811★) | MIT | reference — model def only |
| `sigsep/open-unmix-pytorch` (1.5K★) | MIT | skip for production — SDR ~6, beaten |
| `sevagh/demucs.cpp` (162★) | MIT | skip — CPU port, slower |

**Verdict**: Demucs/Roformer separation works for music underscore. For dialogue stems extracted from mixed track, separation introduces "demucs whoosh" — theatrically unacceptable. For fresh shoots with isolated tracks, skip separation entirely.

## Dialogue mastering / speech enhancement

| Tool | License | Verdict |
|---|---|---|
| `Rikorose/DeepFilterNet` (4.2K★) | Apache+MIT dual | install — DFN3, 48 kHz full-band. Theatrically acceptable for moderate noise; over-processed on clean dialogue. **Use for field audio; bypass for studio.** |
| `xiph/rnnoise` (5.6K★) | BSD-3 | install via ffmpeg `arnndn` — lower quality than DFN3 but lower-latency. Use as gentle gate, not primary. |
| `Audio-WestlakeU/FullSubNet` (603★) | MIT | reference — 16 kHz band-limited, fails 48 kHz cinema spec |

### OSS gaps in dialogue mastering

**No OSS equivalent of iZotope RX, Acon DeNoise, or Nugen ISL.** Specifically missing:
- Mouth-click / breath removal (no OSS spectral repair)
- Spectral repair at RX-7 quality
- De-reverb (research models exist but no production tool)

### DIY broadcast vocal chain (build as FSH skill)

```
1. deepFilter (DFN3) — gentle noise-floor reduction
2. LSP sc_compressor_mono — sidechain HPF 80Hz, gentle 2:1 around -18 dB
3. LSP mb_compressor as de-esser (only 5-8 kHz band reduction)
4. LSP para_equalizer_x16 — HPF 80Hz, presence boost 3-5 kHz
5. ZAM ZaMaximX2 — output limiter at -2 dBTP cinema, -1 dBTP streaming
6. ffmpeg loudnorm two-pass to -27 LUFS cinema / -23 LUFS broadcast
```

## What we CAN deliver theatrically with OSS

- **DCI-compliant 24-bit 48 kHz multichannel PCM WAV stems** (L/C/R/Ls/Rs/LFE) ready for handoff
- **EBU R128 / ATSC A/85 / Netflix loudness-conformant mixes**. Will pass Netflix QC.
- **Stereo and 5.1 PCM submasters** of theatrical quality (if dialogue is clean to start). Acceptable for IMAX projection in PCM-only halls.
- **Clean dialogue track** via DFN3 + LSP chain — streaming-acceptable, borderline theatrical (artifacts on whispers).
- **Object-based audio in ITU-R BS.2076 ADM format** via EAR (open NGA, not Dolby).
- **Stem-remixed music underscores** via Roformer + LSP.

## What requires paid mastering (no OSS path)

- Dolby Atmos / DTS:X / IMAX Enhanced bitstreams — proprietary codec licensing
- iZotope RX-grade spectral repair — no OSS equivalent at production quality
- Convincing stereo→5.1 neural upmix — proprietary
- AI mastering trained on commercial reference catalogs — no open-weights model
- Re-recording mix on a calibrated 85 dB SPL stage — it's a room, not software
- Final theatrical print masters certified for IMAX/Atmos exhibition

## Bottom line

For IMAX work: video-edit-cc should deliver a **clean OSS-mastered stereo + 5.1 PCM submaster + isolated stems** to a commercial mastering house that handles Atmos/DTS:X encode. The OSS chain produces excellent **pre-masters**, never final theatrical encodes.

Promising "IMAX-grade" with OSS-only is a misrepresentation. Promising "IMAX-submission-ready 5.1 PCM with Netflix-spec loudness" is honest and achievable.
