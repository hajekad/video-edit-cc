---
description: Propose, source, sync, and document music for the project. Three modes per artifact lifecycle.
argument-hint: <project-name> [--mode internal-reference|baked-royalty-free|baked-licensed]
---

# /music — propose, source, sync, document

End-to-end music workflow. Picks the right mode from the project's
delivery shape, sources a track, computes sync timecodes, bakes into
the relevant variant(s), writes the cues sheet, updates the manifest.

This command is the **only** correct path to music in FSH. Don't
hand-roll an audio overlay in ffmpeg — that bypasses mode-selection,
the cues sheet, and the rights audit.

## What to do

1. **cd** into `/work/$1/`. Verify `manifest.stage` ≥ `audio-finalized`.
   The picture lock + master.srt must exist; music is the LAST audio
   layer.

2. **Determine the mode.** Read `manifest.music.mode` if already set
   (carried from `/inventory`'s brief-derivation pass). If null, derive
   from `manifest.delivery.preset` via the
   `music_default_mode` field in `/opt/claude-config/delivery-presets.json`.
   Then verify against the artifact lifecycle:

   - Reels / TikTok with `internal_review` + `platform_clean` variants
     → **`internal-reference`** for the internal_review only; no music
     in platform_clean.
   - YouTube long-form / Shorts / LinkedIn / broadcast
     → **`baked-royalty-free`** unless `manifest.music.license_proof`
     is set.
   - User explicitly named a copyrighted track AND license_proof
     exists → **`baked-licensed`**.

   Record the chosen mode + rationale in `manifest.music.mode` +
   `manifest.music.mode_why`.

3. **Source the track.** Order of attempts (from
   `fsh-royalty-free-music` skill, in this exact order):

   **3a. Trend-scout** the audience first — what tracks are peer
   brands in the same persona/vertical using on Reels/TikTok right
   now?
   ```bash
   /opt/claude-config/tools/trend-scout \
       --audience "$(jq -r '.audience_persona' manifest.json)" \
       --vertical "$VERTICAL" \
       --region "$REGION" \
       --peer-brands "$PEER_BRANDS" \
       --out edit/music/trend_candidates.json
   ```
   The agent picks the top-ranked candidate that aligns with the
   persona's mood band + brand voice (not just the highest-scoring
   one — editorial judgment per `fsh-music-mood-bridge` § Q1-Q3).

   **3b. Pitch-fetch the candidate** via yt-dlp:
   ```bash
   /opt/claude-config/tools/pitch-music-fetch "$SLUG" \
       --url "<youtube-url-from-trend-scout>"
   # OR with a trim around the cut's payoff beat:
   /opt/claude-config/tools/pitch-music-fetch "$SLUG" \
       --url "<url>" --start 22 --duration 30
   ```
   This records `manifest.music.source = "yt-dlp-fetch"` and
   `license_status = "pitch-fair-use"`. The `build-variants` tool
   sees this signal and auto-applies the `PITCH PREVIEW — NOT FOR
   DISTRIBUTION` watermark to `_INTERNAL_REVIEW.mp4`.

   **3c. Fallback to user-supplied** if user dropped a file at
   `/assets/<id>/music/`. Run the merge directly:
   ```bash
   python /work/$1/edit/add_music.py /assets/$1/music/<file>
   ```

   **3d. Fallback to royalty-free corpus** via `find_music()` ONLY
   when no peer-brand trending candidate exists AND user didn't drop
   a file. Persona criteria:
   ```python
   persona = yaml.safe_load(open("/agents/fsh-music-mood-bridge/personas.yaml"))[manifest["audience_persona"]]
   candidates = find_music(
       mood=persona["mood_keywords"],
       bpm=tuple(persona["bpm"]),
       duration_s=tuple(persona["duration_target_s"]),
       genres=persona["genres"],
   )
   ```
   Royalty-free tracks ship without the pitch watermark because
   they're legally distributable.

   **3e. Drop-in scaffold** ONLY when 3a-3d all fail.
   `/opt/claude-config/tools/dropin-scaffold "$SLUG" music`. The user
   may never fill this; agent ships `platform_clean` only with
   `pending_music` marker if so.

   See `agents/fsh-royalty-free-music/SKILL.md` § Mode 2 for the full
   doctrine on why pitch-fetch is the default and not a workaround.

4. **Pick the winning candidate** via the editorial-judgment pass in
   `agents/fsh-music-mood-bridge/SKILL.md`. The persona match isn't
   enough — verify the track passes the "should music be here at all?"
   Q1 and the "drop pattern" Q2 for the cut's structural beats.

5. **Compute sync timecodes.** Read `edit/edl.json` to find structural
   beats:
   - Hook (0:00–0:03)
   - Money line(s) — from transcript + strategy.md
   - Section transitions
   - Tail (last 1–2s)

   For each beat, decide if music ducks (-12dB under dialogue), swells
   (+3dB on visual reveal), or drops (mute for "Murch silence" beats).
   Write these as a JSON dict to
   `/work/$1/edit/music/cues.json`.

6. **Bake** music into the variant(s) where the mode allows:
   - `internal-reference` → bake into `internal_review` variant ONLY.
     Filename MUST carry `_INTERNAL_REVIEW`. Use sidechain compression
     keyed off the dialogue stem: `ffmpeg -i base.mp4 -i music.mp3
     -filter_complex "[1:a]sidechaincompress=...,volume=...[bgm]; [0:a][bgm]amix=..."`.
   - `baked-royalty-free` / `baked-licensed` → bake into the
     `platform_final` variant. Same sidechain pattern.
   - `none` → no bake.

   The `platform_clean` variant NEVER receives music; only dialogue,
   sfx, ambient. Verify with `ffprobe` that the clean variant's audio
   stream excludes the music bed.

7. **Write the cues sheet** at `/work/$1/docs/music_cues.md` using the
   template in `/opt/claude-config/tools/music-cues-template`. Include:

   - Track title, artist, source URL, license (if applicable)
   - Mode + rationale
   - Full timecode table: in / duck-points / swell / tail-out
   - BPM + key
   - Suggested platform-UI replacements (Reels / TikTok library
     equivalents by mood)
   - Marketing handoff note: "Upload `<filename>_CLEAN_FOR_UI_MUSIC.mp4`
     muted, add the licensed track at these timecodes"

   The cues sheet is the deliverable to the marketing team alongside
   the variants. Without it, marketing can't replicate the sync.

8. **Update the Music Rights file** at
   `/work/$1/docs/music_rights.md` per `fsh-royalty-free-music`
   protocol. Modes:
   - `baked-royalty-free` → full attribution, license terms, rights-cleared date
   - `internal-reference` → mark "INTERNAL ONLY — NOT FOR DISTRIBUTION",
     name the reference track + source for audit trail
   - `baked-licensed` → license_proof_path reference + track ID

9. **Commit** + advance manifest. Music is the last audio layer; after
   this the project moves toward `rendered` / `delivered` per the
   normal pipeline.

## What NOT to do

- Don't bake music into `platform_clean` variants. Ever. That defeats
  the entire IG-add-music-in-UI workflow.
- Don't ask the user "should I add music?" — derive from
  `manifest.audience_persona` + `fsh-music-mood-bridge` Q1 ("should
  music be here at all"). The user is the engineer; they don't pick
  tracks.
- Don't use Google Image Search or generic YouTube music for licensed
  delivery. Either royalty-free corpus or `license_proof` required.
- Don't skip the cues sheet. The cues sheet is what makes the
  internal-reference pattern usable by marketing.
- Don't bake at uniform volume. Always sidechain duck under dialogue
  (-12dB minimum, -18dB safer floor).

## Why this exists

Smoke test #1 needed three user reprompts to extract music intent.
Hard-coding the mode-selection + variant-routing + cues sheet here
means future projects derive it from the brief automatically. The
agent's `fsh-music-mood-bridge` skill answers WHAT and WHEN; this
command handles HOW.
