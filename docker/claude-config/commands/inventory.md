---
description: Inventory + transcribe + automatic brief-derivation. Stop before strategy.
argument-hint: <project-name>
---

# /inventory — probe + transcribe + derive brief intent, no cuts

Same as `/edit $1` up through stage `inventoried`, then stop. Useful when
the user wants to review the packed transcript before committing to a
strategy.

This command also runs the **brief-interpretation pass** so the agent
never advances to `/plan` with a thin literal-read of the brief.
The doctrine lives at `/docs/BRIEF_INTERPRETATION.md` — re-read it on
every project.

## What to do

1. Scaffold workspace at `/work/$1/` via
   `/opt/claude-config/scaffold-project.sh $1` (nested IDs OK; zips are
   auto-quarantined to `deliveries/`, never extracted).

2. **ffprobe** every input file in `raw/`:
   ```bash
   for f in /work/$1/raw/**/*; do
       [ -f "$f" ] || continue
       ffprobe -v error -print_format json -show_format -show_streams "$f"
   done
   ```
   Push duration, fps, resolution, codec, audio_sample_rate, rotation
   flag, and observed orientation (composed-vertical vs landscape) into
   `manifest.inputs[]`. Sample 3 thumbnails per source for the visual
   pass.

2a. **Mandatory orientation-check on every video source.** Smoke test
    #2 shipped a cut where every Sony VVHA*.MP4 was framed wrong
    because the agent ASSUMED orientation instead of TESTING it. Smoke
    test #1 — different agent, same footage — had figured it out by
    running both orientations side-by-side. The fix is: never assume.

    Read `/docs/SOURCE_QUIRKS.md` first. Then for every video source:
    ```bash
    /opt/claude-config/tools/orientation-check /work/$1/raw/<file>
    ```
    Each call produces a 6-frame composite (3 timestamps × 2
    orientations: as-stored + transpose=2) at
    `/work/$1/edit/orient_check/<stem>_orientations.jpg`. Read every
    composite. Pick the orientation where subjects stand upright,
    horizons are horizontal, text reads left-to-right.

    Record the decision into `manifest.inputs[<i>].quirks[]`:
    ```json
    {
      "id": "<matched-quirk-id from SOURCE_QUIRKS.md>",
      "fix": "<one-line ffmpeg filter prefix>",
      "evidence": "/work/$1/edit/orient_check/<stem>_orientations.jpg",
      "confirmed_by": "visual-comparison"
    }
    ```

    Common matches:
    - `sony-vertical-composed-stored-landscape` → `transpose=2` first
    - `iphone-rotation-metadata-respected` → no transpose
    - `gopro-anamorphic-squeezed` → SAR-to-DAR scale before crop
    - `dji-flat-log-needs-grade` → corrective LUT/eq before delivery

    A source without a recorded quirk decision is NOT allowed to leave
    inventoried stage. Pipeline-gates enforces this.

3. **Surface read** of the brief. Read `/assets/$1/prompt.txt` if
   present, otherwise the conversation-context brief. Save the literal
   text verbatim to `manifest.brief_intent.surface`.

4. **Transcribe** every input via the `asr` wrapper. This picks the
   right backend automatically (faster-whisper by default; WhisperX
   only when `--diarize` is explicitly requested AND its pyannote
   dependency imports cleanly):
   ```bash
   /opt/claude-config/tools/asr /work/$1/raw/<file> \
       --language cs --model large-v3 \
       --out /work/$1/edit/transcripts/<stem>.json
   # add --diarize for multi-speaker interviews; skip for B-roll/single speaker
   ```
   Word-level timestamps in WhisperX-compatible JSON regardless of
   backend. Cache per source — never re-transcribe unchanged input.
   For B-roll / industrial-ambient projects where no dialogue drives
   the cut, write a `docs/transcripts_skipped.md` note and skip — the
   audience_research.md + strategy.md are sufficient to advance.

5. **Pack** transcripts into `/work/$1/edit/takes_packed.md` —
   phrase-level, break on silence ≥ 0.5s OR speaker change.

6. **Signal read** — for each source, derive:
   - Orientation (vertical / landscape / mixed) → suggests platform
   - Visible logos / branded PPE / name patches → identify the brand
   - Setting register (industrial / retail / wedding / talking-head / drone) → suggests audience persona
   - Spoken language → caption burn language
   - Audio character (lavalier / handheld / ambient) → music-bed presence
   Write each signal + its inference + a WHY line into
   `manifest.brief_intent.signals[]`.

7. **Automatic-research pass** (per BRIEF_INTERPRETATION.md):
   - If a brand is identifiable from any frame or transcript, WebFetch
     its official press/media page. Save logo to
     `/work/$1/brand/logo.<ext>`. Save brand colors to
     `manifest.brand.primary_color` / `secondary_color`. Save the press
     URL to `manifest.brand.official_press_url`. Never use Google image
     search; only official press pages.
   - Match the subject to a persona key in
     `/agents/fsh-music-mood-bridge/personas.yaml`. Save key to
     `manifest.audience_persona`. If no existing key fits, ADD a new
     persona entry to the yaml with its rationale and use the new key.

8. **Audience read** — combine signals + brief keywords → derive:
   - `delivery.preset` from `/opt/claude-config/delivery-presets.json`
     (Reels / Shorts / LinkedIn / YouTube / broadcast)
   - `delivery.variants` (e.g., `[internal_review, platform_clean]`
     for Reels; `[platform_final]` for YouTube long-form)
   - `music.mode` (default per the preset; can be overridden per
     editorial judgment from fsh-music-mood-bridge)
   - `subtitles.language` (from transcript language detection)
   Write each with a WHY line into `manifest.brief_intent`.

9. **Set `manifest.brief_intent.derived = true`** so downstream
   stages can rely on it. Update `manifest.stage = inventoried`.
   Commit.

10. **Report.** Tell the user:
    - Source count, total runtime, language(s) detected.
    - The derived intent block (one paragraph: platform, audience,
      brand, delivery pattern). Phrase it as "I'm inferring X because
      Y" so they can correct in one line if wrong.
    - Suggest `/plan $1` when ready.

## What NOT to do

- Do NOT ask the user "should this be a Reels cut?" Derive from
  orientation + brief keywords + audience. They audit on return.
- Do NOT skip the automatic-research pass even when the brief seems
  unambiguous — brand-asset retrieval is free trust capital.
- Do NOT record inferences without WHY lines. Inferences without
  rationale aren't auditable.
- Do NOT advance to `strategy-confirmed` before `brief_intent.derived
  = true`. The reviewer-sub-agent gates this.

## Why this exists

Inventory + transcription + brief-derivation are expensive but
together they let `/plan` write a strategy that already knows the
platform, audience, brand voice, and delivery shape. Without this
pass, every project requires the user to reprompt three times to
extract platform, audience, brand. The doctrine in
`/docs/BRIEF_INTERPRETATION.md` is the single source of truth — this
command implements it.
