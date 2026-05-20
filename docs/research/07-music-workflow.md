# Research: music workflow — sourcing, sync, mastering, audience bridge

Background research output from a parallel agent. The base music report.
Four follow-on agents are still running for deeper coverage:
**editorial judgment**, **cinema/IMAX mastering deep-dive**, **audio AI
search/matching**, **max-coverage skills+MCPs sweep** — when those land
they extend this report (especially sections 4 and 5).

## Top 5 must-haves

1. **`mir-aidj/all-in-one`** (765★, MIT) + **`CPJKU/beat_this`** (286★, MIT) — Beat-sync core. all-in-one returns BPM, beats, downbeats AND structural segments labeled `intro/verse/chorus/bridge/break/inst/solo/outro`. Directly solves "land on the chorus." beat_this is the modern PyTorch beat tracker that works on Python 3.12 (madmom is locked to <3.10). Wrap in a Claude Code skill emitting EDL/JSON timeline.

2. **`MTG/essentia` + `LAION-AI/CLAP`** — Tag + retrieve. Essentia for hard features (BPM/key/danceability/valence/genre/mood-cluster — AGPL, **subprocess only, never import**). LAION-CLAP for natural-language text↔audio embeddings — the bridge between "marketing skill says: uplifting motivational corporate" and "here are 12 candidate tracks." Index your local library into SQLite + faiss vector store; queries are O(ms).

3. **`sergree/matchering`** (2.5K★, GPL-3.0) + **`trummerschlunk/master_me`** (717★, GPL-3.0) **via `spotify/pedalboard`** (6.1K★, GPL-3.0) + **`csteinmetz1/pyloudnorm`** (772★, MIT) — Mastering chain. matchering = tonal/loudness match to a reference; master_me = multi-band chain (Gate → EQ → Leveler → Knee Comp → Multi-band M/S Comp → Limiter → Brickwall) loaded as VST3 via pedalboard; pyloudnorm = QC verification. Pre-bake reference tracks per delivery target. Loop until measured LUFS matches target ±0.5.

4. **`facebookresearch/demucs`** (10.1K★, MIT) — Stem-aware mixing. Hybrid Transformer separating vocals/drums/bass/other. Required for sidechain ducking (music under dialogue), stem-based remastering, and Atmos-ready stem delivery. Fits comfortably on the 3080 Ti.

5. **A hand-authored royalty-free music aggregator (does NOT exist in OSS).** Modules: FMA (mdeff dataset offline, 106K tracks with BPM/genre/mood pre-tagged) + Jamendo (free API key, 500K CC tracks with mood/BPM/instrument search) + Freesound (OAuth, SFX/ambience) + Pixabay-music scraper + NCS scraper (port from JS) + ccMixter open query API. Single `find_music(mood, bpm, duration, license, era, energy)` interface. ~600 lines. **Single biggest hand-author task and the single biggest competitive moat.**

## Critical numeric targets (LUFS by delivery)

| Use case | Integrated LUFS | True peak | Dynamic range | Channel | Sample/bit |
|---|---|---|---|---|---|
| **Cinema theatrical (IMAX/Dolby)** | dialnorm **−27 LKFS** | −2 dBTP | ≥20 LU | 5.1/7.1/7.1.2 Atmos | 48k/24 |
| Trailers (theatrical) | LEQ(m) ≤ 85 dB (TASA) | — | — | 5.1/7.1 | 48k/24 |
| Commercials (theatrical) | LEQ(m) ≤ 82 dB (SAWA) | — | — | 5.1 | 48k/24 |
| Broadcast (EBU R128) | −23 LUFS ±0.5 | −1 dBTP | LRA ≤ 10–15 LU | Stereo/5.1 | 48k/24 |
| YouTube/streaming | −14 LUFS | −1 dBTP | — | Stereo | 48k/24 |
| TikTok-style | −9 LUFS (de facto) | −1 dBTP | — | Stereo | 48k |
| Atmos home (Netflix) | dialnorm −27 LKFS | −1 dBTP | — | 7.1.4 Atmos | 48k/24 |

**Critical**: the agent must branch on delivery target. NEVER collapse to one LUFS number. IMAX-bound output requires dynamic range preservation = disabling normalization, monitoring at reference level (85 dB SPL @ −20 dBFS).

## Trending data — brutal honesty

- ✅ **TikTok Creative Center** (`ads.tiktok.com/business/creativecenter/inspiration/popular/music/pc/en`) — public HTML page, no login, filters by region + genre + mood + trending-this-week. **Single best free source.** Hand-author scraper (~150 lines).
- ✅ `guoguo12/billboard-charts` (432★) — Billboard Hot 100, free, working.
- ✅ `Q-Bukold/TikTok-Content-Scraper` (93★) — TikTok sound metadata extraction, no login, currently working.
- ❌ Spotify/Apple/Shazam per-demographic — paid-API territory only.
- ❌ YouTube Music Charts — no clean scraper; charts.youtube.com requires playwright workaround.

**Verdict**: build around TikTok Creative Center + Billboard. Accept the rest as a gap. Use a static Nielsen/YPulse-derived demographic→genre table as a baseline that doesn't update real-time.

## Royalty-free sourcing — verdicts

| Source | Status | How to use |
|---|---|---|
| **FMA** | `mdeff/fma` dataset (2.6K★, MIT) — 106,574 tracks, BPM/genre/mood pre-tagged | Clone the metadata; index offline; no live API |
| **Jamendo** | Free API key (no credit card) | Direct `requests` calls; mood/BPM/instrument search supported |
| **Freesound** | `MTG/freesound-python` (153★, MIT) + free OAuth2 | SFX + ambience layer (not full music) |
| **CCMixter** | Public `ccHost` query API, no key | 30-line `requests` wrapper |
| **NCS** | `KaninchenSpeed/NoCopyrightSounds-API` (24★, GPL, **JS**) | Port to Python, ~100 lines |
| **Bensound** | `israel-dryer/Bensound-Python-API` (10★) | Read 200 lines, write our own |
| **Pixabay Music** | No public scraper exists | Hand-author ~80 lines |
| **Mixkit** | No scraper | Hand-author |
| **Uppbeat** | Blocked behind login | **Skip** |
| **YouTube Audio Library** | Moved behind YouTube Studio in 2018, all scrapers broken | **Skip** — catalog is largely on Pixabay anyway |
| **Artlist downloader** (`xNasuni/artlist-downloader`) | Violates ToS | **Skip** — legal landmine |
| **SoundCloud/Bandcamp** (`Miserlou/SoundScrape`) | License-checking is on you | Reference-only |

## Beat detection ranking (production)

| Library | Best for | Verdict |
|---|---|---|
| **all-in-one** (`mir-aidj/all-in-one`, 765★) | Full pipeline: BPM + beats + downbeats + chorus/verse boundaries | **Clone** |
| **beat_this** (`CPJKU/beat_this`, 286★, MIT) | Modern PyTorch beat tracker, Python 3.12-compatible | **Clone** |
| **BeatNet** (`mjhydri/BeatNet`, 480★, CC-BY) | Joint beat/downbeat/tempo/meter; 4 modes (streaming/realtime/online/offline) | **Clone** when downbeat-only |
| **madmom** (`CPJKU/madmom`, 1.6K★) | Academic gold standard, but locked to Python <3.10 | Reference-only |
| **librosa** (8.4K★) | Already a hard dep; onset-based beat tracker fine for clean pop only | Keep for features, not authoritative beats |
| **aubio** (3.7K★, GPL-3.0) | Older onset DSP, beaten on accuracy + GPL contamination | **Skip** |

## Marketing-audience → music-mood — the hand-author gap

No turnkey OSS skill maps personas to music criteria. The bridge is:

```
marketing_persona → {genre_set, BPM_range, energy, valence, era, vocal_pref}
                  → Essentia/musicnn tags on local library
                  → CLAP query for natural-language mood overlay
                  → ranked candidate tracks
```

**100–200 line YAML lookup + CLAP retriever.** Example mappings you'll have to encode:

```yaml
"Gen-Z fitness creators on TikTok":
  genres: [hyperpop, trap, drill, jersey-club, dance-pop, brazilian-funk]
  bpm: [120, 160]
  era: [2022, 2026]
  energy: [0.75, 1.0]
  valence: [0.5, 1.0]
  vocal: optional
  duration_target: 15-60s
  trend_source: tiktok_creative_center

"B2B SaaS execs on LinkedIn":
  genres: [corporate-uplifting, ambient-electronic, indie-folk, neo-classical]
  bpm: [90, 120]
  era: [2015, 2026]
  energy: [0.4, 0.7]
  valence: [0.6, 0.9]
  vocal: instrumental_preferred
  duration_target: 30-120s
  trend_source: none
```

## Recommended mastering chain for FotoStudioH (OSS, local)

```
[input video audio]
  → demucs (separate music/dialogue/SFX stems)
  → dialogue: ffmpeg highpass(60Hz) + pyloudnorm to -27 LUFS short-term
  → music: matchering against curated reference per delivery target
  → sidechain ducking: ffmpeg sidechaincompress(music, dialogue)
  → sum stems
  → pedalboard.load_plugin('master_me.vst3') with preset = {cinema|broadcast|streaming}
  → pyloudnorm verification: assert |LUFS - target| < 0.5
  → ffmpeg encode at 48k/24 (cinema) or 48k/16 (web)
```

## Brutal-honesty gaps (no OSS today)

1. **Unified royalty-free aggregator with mood/BPM/duration search** — does not exist. ~600 lines.
2. **Demographic→music spec mapping table** — does not exist as code. ~200 lines YAML from Nielsen/YPulse/industry BPM tables.
3. **Marketing-to-music agent skill** — no OSS wraps Essentia + CLAP + personas. Hand-author.
4. **Cinema/IMAX Atmos mastering** — OSS stops at 7.1 multichannel PCM. ADM-BWF + Atmos rendering require Dolby's proprietary tools. **Promise stem delivery up to 7.1.4 PCM; do not promise an Atmos master.**
5. **Real-time per-demographic trending data** — outside paid APIs, only TikTok Creative Center HTML scrape works at scale.
6. **Beat-sync editing skill for Claude Code** — no repo wraps allin1 + beat_this + EDL emission. Hand-author ~150 lines.

## 50-line wrappers (no skill scaffolding needed)

- `librosa` — features (mfcc/chroma/mel/onset)
- `pyloudnorm` — LUFS/LRA/true-peak measurement
- `pedalboard` — VST3/AU host
- `essentia.standard` — `RhythmExtractor2013`, `KeyExtractor`, `Danceability`
- `beat_this` — `from beat_this.inference import File2Beats; beats, downbeats = File2Beats()(wav_path)`
- `allin1` — `import allin1; result = allin1.analyze('song.mp3')`
- `demucs.separate.main(['--two-stems=vocals', 'mix.wav'])`
- `openl3` — `emb, ts = openl3.get_audio_embedding(audio, sr)`
- `laion_clap` — `model.get_audio_embedding_from_filelist(...)` + text embeddings
- `mutagen` — read/write ID3 mood/BPM/genre tags into the library
