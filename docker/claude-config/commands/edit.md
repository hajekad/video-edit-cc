---
description: Top-level entrypoint. Edit a project end-to-end from /assets input.
argument-hint: <project-name> [optional-prompt]
---

# /edit — full pipeline driver

Run the complete FotoStudioH pipeline on the project at `/assets/$1/`.
Nested asset IDs are OK (e.g. `Q2-2026/PyrolyzaKveten`); the scaffold
slugs them to a flat `/work/<slug>/`.

## What to do

1. **Verify input exists.** If `/assets/$1/` doesn't exist, ask the user
   to drop their files there and try again. Acceptable contents:
   - Loose media files at `/assets/$1/` root (scaffold sweeps into `raw/`)
   - Pre-organized `/assets/$1/raw/` or any user nested layout (scaffold symlinks as-is)
   - Zip archives at `/assets/$1/*.zip` (scaffold QUARANTINES to `deliveries/`; never auto-extracts)
   - Optional `/assets/$1/prompt.txt`

2. **Scaffold the workspace** via the canonical scaffolder. Do NOT
   `mkdir` inside `/assets/$1/` — raw assets are immutable and the
   scaffold handles structure on its own:
   ```bash
   /opt/claude-config/scaffold-project.sh "$1"
   ```
   The scaffolder creates `/work/<slug>/` with `edit/`, `docs/`,
   `.claude/state/`, a symlinked `raw/`, `manifest.json` (full schema:
   `brief_intent`, `audience_persona`, `brand`, `music`,
   `delivery.variants`, etc.), `project.md`, and git init.

3. **Run the three-pass brief read** per `/docs/BRIEF_INTERPRETATION.md`.
   This is non-negotiable — the agent that skips it ships generic edits
   and needs reprompts:
   - Surface read: the literal brief in `prompt.txt` or chat context →
     `manifest.brief_intent.surface`
   - Signal read: footage orientation, visible brand, register, language →
     `manifest.brief_intent.signals[]` with WHY lines
   - Audience read: derive platform preset from
     `/opt/claude-config/delivery-presets.json`, derive persona from
     `/agents/fsh-music-mood-bridge/personas.yaml`, derive
     `delivery.variants`, derive `music.mode` from artifact lifecycle →
     `manifest.brief_intent.audience` with WHY lines
   - Automatic-research pass: when a brand is identifiable, fetch its
     official press page (or call `dropin-scaffold logo` on classifier
     denial). Match persona to subject. Write
     `manifest.audience_persona` + `manifest.brand.*`.
   - Set `manifest.brief_intent.derived = true`. Write
     `docs/audience_research.md` as a first-class artifact.

4. **ffprobe** every input under `raw/` (walk one level deep — scaffold
   may have left the user's nested folder layout intact). Push duration,
   fps, resolution, codec, audio info, rotation flag, observed
   orientation into `manifest.inputs[]`. Sample 3 thumbnails per source.

5. **Transcribe** via the baked WhisperX large-v3 model at
   `$FSH_WHISPER_MODEL_DIR` (default `/opt/whisper-models/`):
   ```bash
   /opt/ml-venv/bin/python -c "
   from faster_whisper import WhisperModel
   m = WhisperModel('large-v3',
       download_root='/opt/whisper-models',
       device='cuda', compute_type='float16')
   # ... transcribe each source, cache per source
   "
   ```
   Word-level timestamps. Cache per source — never re-transcribe
   unchanged input. Pack into `edit/takes_packed.md`.

6. **Hand off to the continuous-worker loop.** Set `cd /work/<slug>` so
   `loop-not-done.sh` sees this as the active project. The Stop hook
   chain directs each subsequent stage. Pipeline gates
   (`pipeline-gates.sh`) refuse to advance past `inventoried` unless
   `brief_intent.derived == true` and `docs/audience_research.md`
   exists, and refuse to advance past `audio-finalized` unless
   `docs/music_cues.md` exists when `music.mode != none`.

## When NOT to use `/edit`

- For an existing project where you already know the stage: just `cd
  /work/<slug>` and let the loop drive.
- For an inventory-only pass: use `/inventory <project-name>` instead
  — it stops at `inventoried`.
- For URL inputs (YouTube): use `/edit-url <url> [project-name]`
  (separate command, not yet built).

## Hard rules (FSH-specific)

- **Never `mkdir` inside `/assets/<id>/`.** Raw assets are immutable;
  scaffold handles structure via symlinks.
- **Never auto-extract zips.** Scaffold quarantines them; the agent
  decides per-zip whether extraction is wanted after sampling.
- **Never skip the brief-interpretation pass.** It's the only way the
  agent reaches `/plan` with platform / audience / brand / music_mode /
  variants already derived.
- **Never bake `_INTERNAL_REVIEW` music into `_CLEAN_FOR_UI_MUSIC` variants.**
  See `audio-finalized.md` § Music — mode-aware, variant-routed.

## Output

Final deliverables land in `/assets/$1/output/`. For Reels / TikTok with
two-variant delivery:
- `<slug>_INTERNAL_REVIEW.mp4` — proposed music baked at sidechain duck
- `<slug>_CLEAN_FOR_UI_MUSIC.mp4` — picture + dialogue + sfx + ambient,
  no music stem (marketing uploads muted and adds music in the
  platform UI)
- `docs/music_cues.md` — timecode handoff for the platform-UI music add

For YouTube long-form / LinkedIn / broadcast, `platform_final` is the
sole variant; music is baked per `manifest.music.mode`.
