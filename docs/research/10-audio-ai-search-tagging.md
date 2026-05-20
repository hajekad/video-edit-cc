# Research: audio AI — search, similarity, tagging

Background research output from a parallel agent. The bridge between
"marketing says use upbeat tech" and "here's the actual file path."
Covers CLAP, music tagging, similarity, BPM/key/energy extraction,
audio fingerprinting / dedupe.

## Top 3 must-pip-install

1. **`laion-clap`** — Text-to-music search and embeddings. Music checkpoint `music_audioset_epoch_15_esc_90.14.pt` (HTSAT-base + RoBERTa). 90.14% ESC50, 71% GTZAN. ~600MB on disk, ~1.5GB VRAM. 512-dim joint text/audio embedding. The primary search engine.

2. **`essentia-tensorflow` (or ONNX models via `onnxruntime-gpu`)** — Pre-trained genre/mood/instrument/key extractors. The primary tagger. **Use ONNX models with onnxruntime to sidestep AGPL contagion.**

3. **`BeatNet` + `pyacoustid` + `madmom`** — beat/tempo/key + dedupe fingerprints. The metadata layer.

## Top 3 must-clone (reference reading)

1. **`lyramakesmusic/clap-interrogator`** (~21★) — canonical "embed + tag with custom JSON taglist" recipe. Multiprocessing batch pattern + JSON-tag-list approach we copy.

2. **`NeptuneHub/AudioMuse-AI`** (1.7K★, **AGPL**) — full working blueprint of self-hosted library tagger + similarity engine using CLAP + librosa + ONNX. **Read for architecture, don't fork (AGPL).**

3. **`MTG/mtg-jamendo-dataset`** — taxonomy + label vocabulary to adopt so our tags match what pre-trained models output.

## The architecture (chain to build)

```
INGEST (file):
  → pyacoustid fpcalc fingerprint → dedupe table [skip if dup]
  → ffmpeg decode @ 48kHz mono
  → librosa: loudness, RMS energy curve, spectral flatness → "energy track" json
  → BeatNet (CUDA): beat times, downbeats, tempo, meter → bpm/tempo
  → Essentia ONNX models (onnxruntime-gpu):
       discogs-effnet (400 styles) → genre tags + 1280-dim embedding
       mtg_jamendo_genre / mood_* → mood/genre tag vector
       KeyExtractor → key + scale
  → LAION-CLAP (music ckpt, HTSAT-base) → 512-dim joint embedding
  → FAISS index: store CLAP vector + style embedding + metadata in SQLite

QUERY:
  text query "upbeat tech, no vocals, 120 BPM"
    → LAION-CLAP text embed (512-d)
    → FAISS cosine top-K filtered by bpm window + has_vocals=False
    → return ranked file paths

  reference track query "sounds like /path/to/ref.wav"
    → LAION-CLAP audio embed
    → FAISS top-K by cosine over CLAP space
```

## VRAM budget (12GB)

| Component | VRAM |
|---|---|
| WhisperX large-v3 (already running) | ~5 GB |
| LAION-CLAP music ckpt (HTSAT-base) | ~1.5 GB |
| Essentia ONNX taggers | ~500 MB |
| BeatNet CRNN | ~500 MB |
| MERT-95M (optional) | ~1.5 GB |
| **Worst-case parallel** | **~9 GB — fits** |

Sequential per track: budget collapses to whichever single model is loaded.

## Detailed verdicts

### CLAP family

| Tool | License | Verdict |
|---|---|---|
| `LAION-AI/CLAP` (2.2K★) | CC0-1.0 | **install — primary text-search engine** |
| `microsoft/CLAP` msclap (662★) | MIT | reference / A/B comparison only |
| `NeptuneHub/AudioMuse-AI-DCLAP` (6★) | AGPL-3.0 | reference; AGPL is a blocker |
| `tencent-ailab/MuQ` (339★) | MIT (code) | install secondary — slightly better on perceptual music similarity (72.4% vs 71.9%) |
| `lyramakesmusic/clap-interrogator` (~21★) | mixed | reference recipe |

### Tagging

| Tool | License | Verdict |
|---|---|---|
| `MTG/essentia` (3.6K★) | AGPL-3.0 | **install via ONNX models + onnxruntime to dodge AGPL.** Crown jewel: discogs-effnet (400 classes), mtg_jamendo_genre (87), msd-musicnn; mood: aggressive/happy/party/relaxed/sad, arousal/valence regression; instrument, danceability, voice/instrumental, tonality. |
| `jordipons/musicnn` (700★) | ISC | skip — use Essentia ONNX of same weights |
| `marl/openl3` (589★) | MIT | skip — TF1.x dependency, superseded by CLAP/MERT |
| `qiuqiangkong/panns_inference` (262★) | MIT | install complementary — detect "has vocals?", "has drums?", "is acoustic?" via 527 AudioSet classes. ~500MB VRAM. |
| `m-a-p/MERT-v1-95M` (459★) | Apache-2 code, **CC-BY-NC-4.0 weights** | skip if commercial — non-commercial blocks ship use |

### Similarity

| Tool | License | Verdict |
|---|---|---|
| `dominikschnitzer/musly` (146★) | MPL-2.0 | skip — CLAP+FAISS does it better |
| **LAION-CLAP + FAISS** | CC0 + MIT | **this is the architecture** |
| OpenAI Jukebox encoder | n/a | skip — 7-16 GB VRAM, too heavy |
| `mimbres/neural-audio-fp` (209★) | MIT | reference only — wrong problem (Shazam identity vs perceptual similarity) |

### BPM / key / energy

| Tool | License | Verdict |
|---|---|---|
| `CPJKU/madmom` (1.6K★) | BSD-style | **install — SOTA reference, slower (CPU-bound, 1-2× realtime)** |
| `mjhydri/BeatNet` (480★) | CC-BY-4.0 | **install — primary beat/tempo for cinematic + variable-tempo material; CUDA support** |
| `librosa/librosa` (8.4K★) | ISC | install (transitive dep) — use for energy/dynamics, defer beat to BeatNet |
| `aubio/aubio` (3.7K★) | **GPL-3.0** | **skip — GPL contagion** |
| `c4dm/qm-vamp-plugins` (36★+42★) | **GPL-2.0** | reference-only oracle for key/chord validation |
| Essentia `KeyExtractor` | (AGPL via ONNX dodge) | install — fast key/scale |

### Audio fingerprinting / dedupe

| Tool | License | Verdict |
|---|---|---|
| `acoustid/chromaprint` + `beetbox/pyacoustid` (1.3K + 391★) | LGPL-2.1 / MIT | **install — primary dedupe + commercial-track detect** |
| `worldveil/dejavu` (6.8K★) | MIT | reference — overkill, needs SQL DB |
| `dpwe/audfprint` (602★) | MIT | install for prototyping if chromaprint hits issues; skip production |

## License watch-outs (if FSH ships commercially)

Hard blockers:
- **MERT model weights**: CC-BY-NC-4.0 → NON-COMMERCIAL only. Skip.
- **AudioMuse-AI / DCLAP**: AGPL-3.0 → read only, don't fork.
- **aubio**: GPL-3.0 → skip entirely.
- **QM Vamp Plugins / Sonic Annotator**: GPL-2.0 → reference-only.
- **Essentia C++ library**: AGPL-3.0 → **use ONNX models with plain onnxruntime to sidestep** (outputs are model files, not Essentia code).

Friendly:
- LAION-CLAP code: CC0-1.0 (very permissive)
- microsoft/CLAP: MIT
- BeatNet: CC-BY-4.0 (attribution only)
- madmom: BSD-style
- chromaprint: LGPL-2.1 (dynamic-link via fpcalc subprocess is fine)
- pyacoustid: MIT
- librosa: ISC
