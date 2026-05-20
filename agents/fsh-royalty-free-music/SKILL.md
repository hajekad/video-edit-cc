---
name: fsh-royalty-free-music
description: Unified royalty-free music sourcing across FMA, Jamendo, Freesound, ccMixter, Pixabay, Mixkit, NCS. Returns ranked candidate tracks for a query (mood / BPM / duration / license / era). Default search space is royalty-free; the agent ONLY queries copyrighted libraries when the user explicitly authorizes it. Use when the strategy doc calls for music and the project doesn't have a user-supplied track.
version: 1.0.0
---

# Royalty-Free Music Aggregator — Search Layer

The research surveyed every public OSS music-source aggregator.
**Nothing unifies these libraries behind a single search interface.**
This file is the FotoStudioH-native design + adapter contracts for
building one.

## Strict default behavior

**Royalty-free FIRST.** The agent queries only these libraries by
default:
- Free Music Archive (FMA) — `mdeff/fma` static dataset (106K tracks
  pre-tagged with BPM/genre/mood)
- Jamendo — free API key (no credit card)
- Freesound — for SFX / ambience, not music tracks
- ccMixter — open `ccHost` query API, no key
- Pixabay Music — hand-authored scraper
- Mixkit — hand-authored scraper
- NCS (No Copyright Sounds) — port of `KaninchenSpeed` JS scraper
- (Optional) Bensound

The agent goes OUTSIDE royalty-free **only** when the user explicitly
authorizes it in the strategy doc (e.g., `manifest.music.copyright_ok
= true` with a written rationale). Without that flag, copyrighted
libraries are skipped without prompt.

## Architecture

A single `find_music()` function aggregates the adapters:

```python
def find_music(
    mood: str,                    # e.g. "uplifting motivational corporate"
    bpm: tuple[int, int] = None,  # e.g. (110, 130)
    duration_s: tuple[int, int] = None,  # e.g. (45, 90)
    license: list[str] = None,    # e.g. ["CC0", "CC-BY"]
    era: tuple[int, int] = None,  # e.g. (2018, 2026)
    energy: tuple[float, float] = None,  # e.g. (0.6, 0.9) — Essentia danceability
    valence: tuple[float, float] = None, # e.g. (0.5, 1.0) — Essentia
    genres: list[str] = None,     # e.g. ["corporate", "ambient-electronic"]
    has_vocals: bool = None,      # None = either; False = instrumental only
    max_results: int = 20,
    sources: list[str] = None,    # None = all royalty-free defaults
) -> list[Candidate]:
    ...
```

Where each `Candidate` carries: `path` (local cache), `title`,
`artist`, `source`, `license`, `bpm`, `key`, `duration_s`, `tags`,
`url`, `clap_embedding` (for downstream similarity).

## Adapter contracts

Each adapter is a separate Python module under `agents/fsh-royalty-free-music/adapters/`. Same interface; different backend.

### `fma_adapter.py` — Free Music Archive
- Reads `mdeff/fma` static dataset (CSV + WAV/MP3 files).
- Pre-tagged with BPM (via Echonest), genre (161 classes), mood.
- Local-only after one-time download of the dataset (~80 GB for `fma_large`).
- For FotoStudioH MVP: use `fma_small` (~8 GB, 8K tracks) until the
  user authorizes the full dataset download.

### `jamendo_adapter.py` — Jamendo
- Uses Jamendo's free API key (no credit card; register at
  developer.jamendo.com).
- Filterable by mood / genre / instrument / BPM / theme.
- Half a million CC tracks.
- Free tier rate-limited; cache aggressively.

### `freesound_adapter.py` — Freesound
- Uses `MTG/freesound-python` (when added as submodule).
- OAuth2 for download. Mostly SFX / ambience / loops.
- Filter to CC0 by default; CC-BY with attribution tracking optional.
- **Not full music tracks** — used for SFX layer of the master mix.

### `ccmixter_adapter.py` — ccMixter
- Open `ccHost` query API at ccmixter.org/query-api. No key required.
- Mostly remixes, vocal acappellas, stems — useful for derivative work.
- Direct `requests` calls; ~30-line wrapper.

### `pixabay_adapter.py` — Pixabay Music
- No documented public API for music endpoints.
- Hand-authored scraper of `pixabay.com/music/search/<query>`.
- ~80 lines (requests + BeautifulSoup or HTML parsing).
- License: Pixabay license (commercial use, no attribution required).

### `mixkit_adapter.py` — Mixkit
- No API. Hand-authored scraper of `mixkit.co/free-stock-music/`.
- Mixkit license (commercial use, attribution recommended).

### `ncs_adapter.py` — NCS (No Copyright Sounds)
- Port of `KaninchenSpeed/NoCopyrightSounds-API` (JS) to Python.
- ~100 lines.
- License: NCS terms (free for monetized content, attribution required).

### `bensound_adapter.py` — Bensound (optional)
- Read `israel-dryer/Bensound-Python-API` source; write a fresh ~80-line wrapper.
- License: per-track varies (free-with-attribution vs paid).

## Query → results pipeline

```
1. NORMALIZE the query:
   - Resolve mood text to LAION-CLAP text embedding (512-d)
   - If genres list given, expand via the Essentia discogs-effnet
     400-class vocabulary (similar genres included)
   - License filter applied as adapter parameter

2. PARALLEL FAN-OUT to all configured adapters:
   - Each returns up to max_results × 3 candidates (over-fetch then rank)
   - Adapter results normalize to the Candidate dataclass

3. UNIFIED RANKING via LAION-CLAP cosine similarity:
   - For each candidate, compute (or cache) the CLAP audio embedding
     by downloading a 30s preview clip and embedding it
   - Sort by cosine(text_embedding, candidate.audio_embedding)
   - Apply hard filters (BPM range, duration, license, era, has_vocals)

4. INDEX cached candidates in a local SQLite + FAISS:
   - Repeat queries hit the cache, not the upstream APIs
   - Embedding only re-computed on cache miss

5. RETURN top-K with all metadata.
```

## When the user provides a track directly

If `/assets/<project>/raw/` contains an audio file the user intends as
the music bed (heuristic: file is in raw/ AND ffprobe detects no video
stream AND the file is longer than 30s), **prefer that track over any
agent-sourced candidate**. The strategy doc records the user's intent
in `manifest.music.user_provided: true`.

The agent still analyzes the provided track (BPM, key, energy, mood
via Essentia + CLAP) so beat-sync and editorial decisions can be made.
But it does NOT swap the track out.

## Caching strategy

- One-time: FMA static dataset under `~/.cache/fsh-music/fma/`
- Per-query: API/scraper responses cached at
  `~/.cache/fsh-music/queries/<sha256(query_json)>.json` for 7 days
- Per-candidate: 30s preview WAV at
  `~/.cache/fsh-music/previews/<source>_<id>.wav` permanently
- Per-candidate: CLAP embedding cached in SQLite, indexed by FAISS

Total cache budget: ~100 GB. Mounted via the named volume in
`docker-compose.yml` (already present as `hf-models` → `/root/.cache`).

## License handling — agent contract

For each candidate the agent uses, write to `/work/<id>/docs/music-rights.md`:

```markdown
# Music Rights

## <track-filename>.mp3
- Source: <FMA | Jamendo | Freesound | ...>
- License: <CC0 | CC-BY | NCS-free-monetized | Pixabay | ...>
- Attribution required: <yes / no>
- Attribution string: "<exact required text>" (if applicable)
- Used in: <project-id>/edit/final.mp4 at 0:00:34 - 0:01:42
- Rights cleared: <date>
```

The reviewer sub-agent (`issue-state-review.sh`) checks this file
exists and is current before allowing the `delivered` stage flip.

## Going outside royalty-free

User can authorize copyrighted use by setting in manifest:

```json
{
  "music": {
    "copyright_ok": true,
    "copyright_rationale": "Client has YouTube ContentID monetization-share deal with [label]",
    "additional_sources": ["spotify_top_charts", "tiktok_creative_center"]
  }
}
```

When this flag is set:
- Extend search to TikTok Creative Center HTML scrape (the one
  practical "trending per audience" source — see
  `docs/research/07-music-workflow.md` § Trending data)
- Extend to Billboard Hot 100 via `guoguo12/billboard-charts`
- For each candidate, run `chromaprint + AcoustID` to check if the
  track is in the commercial-music corpus
- **ALWAYS warn the user** in the delivery summary that copyrighted
  music was used, naming the tracks + sources

The agent NEVER assumes copyright_ok = true. The user must say so
explicitly.

## What this skill CANNOT do

- **Real-time per-demographic trending** outside what TikTok Creative
  Center exposes. Spotify/Apple per-cohort charts are paid-only.
- **License enforcement guarantee.** chromaprint + AcoustID catch the
  MusicBrainz/AcoustID corpus; private-label catalogs (Audible Magic
  used by YouTube ContentID) are not visible. Warn the user.
- **Unlimited downloads.** Many of the aggregator sources rate-limit or
  block scrapers. Build in 1-2 second delays between requests, and
  fall back to cached results on 429s.

## Cross-references

- Music editorial judgment (when to add): `agents/fsh-music-mood-bridge/SKILL.md`
- Mastering chain for music bed: `agents/fsh-music-mood-bridge/`,
  `agents/fsh-broadcast-vocal-chain/SKILL.md` (different bar)
- Honest source landscape: `docs/research/07-music-workflow.md`
- Audio AI for matching/tagging: `docs/research/10-audio-ai-search-tagging.md`
- Editorial veto over music choice: `docs/research/09-music-editorial-judgment.md` Q6
