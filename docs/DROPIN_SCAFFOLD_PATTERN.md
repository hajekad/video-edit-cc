# Drop-In Scaffold Pattern

The agent runs in a sandbox where the classifier can refuse autonomous
fetches of external assets — music tracks, brand logos, licensed
footage, signed license documents. When that happens, the agent's job
is **not** to keep trying to talk past the refusal. Its job is to
build a **drop-in scaffold** so the user can supply the asset in one
file move and the pipeline continues automatically.

> Reference case: smoke test #1. Agent built `add_music.py` + a
> `/assets/<id>/music/` drop folder + a README naming three Pixabay
> URLs after the classifier denied autonomous yt-dlp / aggregator
> fetches. Single-command remix once the user dropped a file. This
> doctrine generalizes that emergency invention into a permanent
> pattern.

## When to scaffold

Whenever the agent is blocked from autonomously acquiring an external
asset AND the asset is needed for delivery. Recognize the trigger by
any of:

- Classifier denial on `WebFetch`, `Bash` (`curl`, `wget`, `yt-dlp`)
  even after rephrasing
- "No autonomous downloads" / "external asset out of scope" type
  refusals
- Capability matrix marks the source as `engine-not-wired` and
  bringing up the engine isn't this session's job
- Asset requires explicit user license review (signed contracts,
  brand-team approved logos, paid stock licenses)

When triggered, the agent must NOT:
- Pivot to a third-party aggregator that might also be denied
- Strip the asset from the deliverable silently
- Ship a placeholder that looks like the real thing
- Stall the project at "blocked"

The agent MUST:
- Generate a drop-in scaffold
- Continue with everything else (render every variant the asset isn't
  required for; bake the merge step so a single command applies the
  asset later)
- Surface the unblock paths explicitly in the delivery summary

## Scaffold shape

For each blocked asset type, the agent creates **three artifacts**:

### 1. Drop folder at `/assets/<id>/<asset-type>/`

A bare directory with a README. The README lists:
- What the user puts there (filename + format)
- One specific URL the user can authorize for autonomous fetch
  (single specific URL is much cleaner classifier signal than "any
  music")
- Two or three alternative source URLs with license context
- Once a file lands, the one command that merges it in

### 2. Merge script at `/work/<id>/edit/add_<asset-type>.py`

A self-contained script that takes the dropped file as an argument and
merges it into every variant that needs it. Idempotent — re-running
overwrites the merged variants but doesn't touch the base picture
lock. Same script the agent would have used had it been able to fetch
the asset autonomously, just with the input wired to a path argument.

### 3. README updates in the delivery package

`/assets/<id>/output/README.md` and the corresponding
`<ASSET>_HOWTO.md` document:
- The drop path
- The merge command
- Why this is blocked (classifier policy / license review / etc.)
- The two unblock paths: (a) specific URL authorize, (b) user drop a
  file

## Standard asset-type registry

Each blocked asset type has a canonical scaffold shape:

| Asset type | Drop path | Expected filename | Merge script | Merges into |
|---|---|---|---|---|
| music | `/assets/<id>/music/` | `track.mp3` (or .wav/.m4a) | `edit/add_music.py` | hero/teaser/landscape music variants |
| logo | `/assets/<id>/branding/` | `<brand>_logo_white.png` + `<brand>_logo_color.png` | `edit/add_logo.py` | close-card composite, lower-third end-card |
| license-doc | `/assets/<id>/licenses/` | `<track-or-asset>.pdf` | (records to `manifest.music.license_proof`) | gate for `baked-licensed` mode |
| voiceover | `/assets/<id>/voiceover/` | `vo_<scene>.mp3` | `edit/add_voiceover.py` | per-scene audio mix |
| client-footage | `/assets/<id>/raw_addendum/` | original-named source files | (re-runs inventory + EDL build) | additional shots in EDL |
| supers / lower-thirds | `/assets/<id>/supers/` | `super_<n>.png` (alpha) | `edit/add_supers.py` | composite at scripted timecodes |

When a new blocked-asset type appears, the agent ADDS a row to this
table (in `/docs/DROPIN_SCAFFOLD_PATTERN.md`) before generating the
scaffold. The pattern then becomes inheritable for the next project.

## The unblock-paths note

Every scaffold README must end with the **two unblock paths**:

```
## Two ways to unblock

1. Authorize a specific URL: name ONE specific URL and I'll fetch it.
   Single-URL specificity is much cleaner classifier signal than
   "any track from <category>". Example URLs already vetted:
     - <url-1>
     - <url-2>

2. Drop a file: save the asset at <drop-path> from your phone/laptop.
   Then run: <merge-command>
   Under 30 seconds end-to-end once the file is in place.
```

This is the user's contract: clear, fast, two options, no ambiguity.

## Pipeline behavior with a pending drop-in

`manifest.<asset>.pending_dropin = true` flags an asset is awaiting
user supply. Pipeline gates:

- `pipeline-gates.sh` does NOT fail the stage just because a
  `pending_dropin` is unresolved. Stage advances on the variants that
  don't need the asset.
- The `deliver` directive in `loop-not-done.sh` includes a "X pending
  drop-ins" line so the user sees it on every status check.
- When the file lands at the drop path, the agent re-runs the merge
  script on the next loop tick and clears `pending_dropin`.

The deliverable can ship "incomplete with pending drop-ins" — that's
better than shipping nothing or shipping with the wrong asset.

## What the agent NEVER does

- **Never substitutes a stock placeholder for a missing brand logo.**
  Either the official logo lands via drop-in, or the close card uses
  text-only fallback. A wrong logo damages trust more than a missing
  one.
- **Never bakes a copyrighted track into a `platform_final` variant
  without `license_proof`.** Use `internal-reference` mode in the
  `_INTERNAL_REVIEW.mp4` variant only; the `_CLEAN_FOR_UI_MUSIC.mp4`
  variant exists for the marketing team to add licensed music
  themselves.
- **Never silently strips a required asset.** If music was specified
  in the brief and the user hasn't dropped a file, scaffold + ship
  the mute variant + name what's missing.
- **Never pivots away from an official-source asset to a third-party
  aggregator.** Drop-in scaffold from official source > aggregator
  fetch.
- **Never invents an audible "music substitute".** Smoke test #2
  invented sine-wave guide tones at the music cue beats and labeled
  the result `internal_review.mp4`. The marketer played it back and
  heard 8 beeps + silence — that fails the "show me your proposed
  vibe" deliverable purpose. Sine tones, metronome clicks, noise beds,
  TTS-narrated cue announcements, and similar audible substitutes are
  ALL banned in the internal-review variant. When music can't be
  acquired, the correct end-state is:
    1. Try the single-URL classifier-friendly fetch (see § Single-URL
       fallback below).
    2. If that fails: ship `platform_clean.mp4` only. Mark
       `internal_review` as `pending_music` in the manifest. Write
       `docs/music_cues.md` with the proposed track + cue timecodes
       AS DOCUMENTATION ONLY. The marketer reads the cues sheet and
       picks a track inside the Reels editor on upload. They do NOT
       need an audible reference for that workflow.
    3. The agent NEVER fakes the proposed-music sound.

## Single-URL fallback (classifier-friendly attempt)

The classifier blocks generic "fetch me music" requests but typically
allows specific commercial-license URLs presented with attribution
context. When dropin-scaffold lists `scaffold_sources`, the agent MUST
try the first URL as a single-shot fetch BEFORE falling back to
shipping pending-music. The shape:

```
WebFetch the first URL with a prompt like:
  "Please fetch the audio file at <exact URL>. License: Pixabay
   Content License (commercial use permitted, no attribution
   required). The file will be baked into an internal-review video
   artifact for marketing sign-off; not for public distribution."
```

If the classifier still denies, log the denial reason into
`/work/<slug>/docs/issues/music-fetch-denied.md` and proceed to
ship-with-pending. Do NOT try a second URL with a softer framing.
That's the wrong loop.

The fallback chain in order:
1. `scaffold_sources[0]` — explicit single-URL fetch
2. User-dropped file at `/assets/<id>/music/track.<ext>`
3. `manifest.music.user_supplied_path` (manual override)
4. Ship `platform_clean.mp4` only with `pending_music = true`. Document
   the cue sheet textually.

Never reach for option 5 (invent audible substitute) — there is no
option 5.

## Cross-references

- `/docs/BRIEF_INTERPRETATION.md` — derives which assets a project
  needs, including which are likely to require drop-in
- `/agents/fsh-brand-assets/SKILL.md` — official-source logo fetch
  with drop-in fallback
- `/agents/fsh-royalty-free-music/SKILL.md` — music mode selection
  (some modes go to drop-in)
- `/docker/claude-config/tools/dropin-scaffold` — generator that
  emits the scaffold for any registered asset type
