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

## Three modes (pick by artifact lifecycle, not by blanket rule)

The skill operates in one of three modes per project. Mode lives at
`manifest.music.mode`. The agent picks it by reading the **artifact's
lifecycle** — what happens to the deliverable after the agent hands
it off?

### Mode 1: `baked-royalty-free` (default for public-distribution variants)

Music is sourced from the royalty-free corpus and baked into the
output. Used for:
- YouTube long-form (`youtube-landscape-1080p`, `youtube-landscape-4k`)
- LinkedIn (`linkedin-square`)
- Shorts (`shorts-vertical`)
- Broadcast handoff (`broadcast-mezz`) when no licensed track is supplied
- Any `platform_final` variant

Search corpus: FMA, Jamendo, Pixabay, Mixkit, NCS, ccMixter, YouTube
Audio Library. Default behavior of `find_music()`. Music Rights audit
file is required.

### Mode 2: `internal-reference` (proposal artifacts, not distribution)

The artifact is an **internal review preview** — the marketing team
watches it to approve the editorial direction, then uploads a separate
`platform_clean` variant to the platform and adds licensed music
inside the platform UI. Used for:
- `internal_review` variant of Reels (`reels-vertical`)
- `internal_review` variant of TikTok (`tiktok-vertical`)
- Any artifact whose filename carries `_INTERNAL_REVIEW` suffix
- Client review screeners where the music choice is being proposed,
  not shipped

In this mode the artifact is a **pitch proposal**, not a distribution
copy. Its purpose is to make marketing feel the dollar-to-impact ratio
click in their gut, with the actual proposed track hitting the actual
money beat. Mood-board descriptions and royalty-free stand-ins fail
this purpose — marketing doesn't sign a $50k–$200k sync-license check
on a vibe; they sign when they hear the track they're paying for.

The legal envelope is the same as a creative-agency Cannes-pitch
animatic. It is industry-standard, fair-use-for-proposal work — NOT a
copyright workaround.

**The agent's job — in this order**:

1. **Trend-scout the audience** via
   `/opt/claude-config/tools/trend-scout` (when available — see Tier-2
   doctrine in fsh-music-mood-bridge). Identify what tracks peer
   brands in the same audience persona have been using on the target
   platform in the last 4 weeks. Output is a ranked list of candidate
   audio URLs. If trend-scout isn't wired or returns empty, fall
   through to (2).

2. **Pitch-fetch the top candidate** via
   `/opt/claude-config/tools/pitch-music-fetch`. yt-dlp audio
   extraction; the tool records `manifest.music.source =
   "yt-dlp-fetch"`, `license_status = "pitch-fair-use"`,
   `distribution_allowed = false`. The `build-variants` tool then
   auto-applies the `PITCH PREVIEW — NOT FOR DISTRIBUTION` watermark
   to the `_INTERNAL_REVIEW.mp4` artifact. This is the default path.

3. **User-supplied track** when the user has named a specific song or
   dropped a file at `/assets/<id>/music/`. Use it directly. Same
   watermark applies because the user-named track may still be
   copyrighted; the watermark is keyed off
   `manifest.music.source == "user-supplied"` only when
   `license_proof_path` is null.

4. **Royalty-free corpus** via the `find_music()` aggregator when a
   trending peer-brand candidate isn't identifiable AND the user
   hasn't named a song AND the persona's mood band has a
   genuinely-strong royalty-free match (Pixabay / YouTube Audio
   Library / FMA / Jamendo). Last resort BEFORE drop-in scaffold.
   Watermark NOT applied because royalty-free tracks are legally
   distributable.

5. **Drop-in scaffold** ONLY when 1-4 all fail (no peer-brand recon,
   no fetchable URL, no user-supplied track, no royalty-free match).
   Then call `/opt/claude-config/tools/dropin-scaffold <slug> music`
   to scaffold the user-drops-a-file fallback path. Document in
   `docs/issues/music-acquisition-blocked.md` why 1-4 failed.

6. **Ship `platform_clean` only + pending_music marker.** Only kicks
   in when (5) also fails — i.e., the user is non-technical and the
   drop-in path will never be filled. Produce `platform_clean.mp4`
   alone with `docs/music_cues.md` as the textual handoff. Marketing
   picks a track in the platform editor on upload.

**Why pitch-fetch is the default, not a workaround:**

The user of this system is a director or marketing lead, not an
engineer. They cannot:
- Browse a Cloudflare-protected music library and download the file
- Drop the file at the right path
- Run `python add_music.py /path/to/track.mp3`

If the agent's "music workflow" depends on those steps, the agent has
no music workflow. The pitch-fetch path is the only design that
delivers the actual purpose — a watchable artifact with the real
proposed track — without requiring non-existent user skill.

**NEVER reach for option 6** — there is no option 6. Specifically:
- NEVER generate sine-wave guide tones / metronome clicks / noise
  beds / TTS-narrated cue announcements as a music substitute. The
  internal_review variant either has actual proposed music or it does
  not exist at all.
- NEVER ship an `internal_review.mp4` whose audio stream is
  synthesized "guide tones." Smoke test #2 did this and the marketer
  played back 8 beeps + silence. That fails the deliverable purpose.

The cues sheet at `/work/<id>/docs/music_cues.md` is the canonical
handoff — it tells marketing the exact in/out/duck/swell timecodes so
they can replicate the sync inside the platform UI with whatever the
licensed library serves them. The cues sheet is always written; the
internal_review variant is conditional on options 1-4 succeeding.

This mode is NOT a copyright workaround. It is a recognition that
proposal artifacts are not distribution. See
`/docs/PROMPT.md` § "Calibration: overcautious refusal is also
failure" for the rationale.

### Mode 3: `baked-licensed` (user has explicit license proof)

User has authorized a specific copyrighted track for distribution and
has a license proof on file. Set in manifest:

```json
{
  "music": {
    "mode": "baked-licensed",
    "license_proof": {
      "track": "Artist — Title",
      "license_type": "sync license | YouTube ContentID monetization share | direct purchase",
      "license_doc_path": "/assets/<id>/licenses/<file>.pdf",
      "rationale": "Client has YouTube ContentID monetization-share deal with [label]"
    },
    "additional_sources": ["spotify_top_charts", "tiktok_creative_center"]
  }
}
```

When this mode is active:
- Extend search to TikTok Creative Center HTML scrape (trending per
  audience — see `docs/research/07-music-workflow.md` § Trending data)
- Extend to Billboard Hot 100 via `guoguo12/billboard-charts`
- For each candidate, run `chromaprint + AcoustID` to check the
  commercial-music corpus
- **ALWAYS warn the user** in the delivery summary that copyrighted
  music was used, naming the tracks + sources + license proof path

The agent NEVER assumes `mode = baked-licensed` unless the license
proof path is present and the file exists.

## Mode-selection decision

```
delivery.preset → music_default_mode (from delivery-presets.json)
                ↓
agent reviews artifact lifecycle:
  - Reels / TikTok / IG-style platform add-music-in-UI?
        → internal-reference for internal_review variant
        → "no music" for platform_clean variant
  - YouTube long-form / Shorts / LinkedIn / broadcast?
        → baked-royalty-free (default)
        → baked-licensed (only if license_proof present)
  - User supplied a specific copyrighted track?
        → baked-licensed iff license_proof exists; else internal-reference only
```

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
