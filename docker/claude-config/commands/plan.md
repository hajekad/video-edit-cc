---
description: Propose an edit strategy, write it to docs/strategy.md, self-approve, advance to edl-built.
argument-hint: <project-name>
---

# /plan — strategy proposal (self-approved)

Read the packed transcript + thumbnails + user prompt, propose a
strategy in plain English, write it to `docs/strategy.md`, set
`manifest.strategy.approved = true`, and advance the stage. The user
is an engineer running this system — they do NOT approve cuts. They
audit `docs/strategy.md` on return and roll back if they disagree.

## What to do

1. **cd** into `/work/$1/`. Confirm `manifest.stage` is at least
   `inventoried` AND `manifest.brief_intent.derived == true`. If not,
   run `/inventory $1` first — /plan refuses to advance on a
   brief_intent that hasn't been derived. The doctrine lives at
   `/docs/BRIEF_INTERPRETATION.md`.

2. **Read** the inputs in this order:
   - `/work/$1/manifest.json` → `brief_intent` block (derived by /inventory)
   - `/work/$1/manifest.json` → `audience_persona` + `brand` + `delivery.preset`
   - `/work/$1/edit/takes_packed.md`
   - `/assets/$1/prompt.txt` if present (else the user's chat-level prompt)
   - Any previous `/work/$1/project.md` session notes
   - Sample `timeline-view` PNGs on 1-2 sources for visual context
   - `/opt/claude-config/delivery-presets.json` → look up the preset's
     constraints (resolution, fps, max_duration_s, codec, music_default_mode)
   - `/agents/fsh-music-mood-bridge/personas.yaml` → load the
     persona's mood band + brand_voice + notes

3. **Decide the answers yourself** (don't ask). Pick:
   - Content type (talking head / interview / montage / tutorial / travel / event / corporate / wedding / doc / B2B-industrial / etc. — usually pre-derived in `brief_intent.signals[]`)
   - Target length within the preset's `max_duration_s` and the persona's `duration_target_s`
   - Target aspect from the preset (Reels = 9:16, LinkedIn = 1:1, etc.)
   - Aesthetic direction matching the persona's `brand_voice` (industrial-pride / cinematic / energetic / neutral)
   - Must-preserve moments (from transcript + thumbnails)
   - Must-cut moments (slips, redundant takes, off-thesis material)
   - Animation overlays — gate by persona (NO kinetic typography for B2B-industrial; lower-thirds OK; data viz OK)
   - Subtitle preference — language from `subtitles.language`, style from the preset (`burn-in-default` for LinkedIn; `drawtext-bold-lower-third` for Reels)
   - Color grade matching the brand's voice (cinematic for premium; neutral for documentary; warm for hospitality)
   - Delivery shape — read `delivery.variants[]` set by /inventory (e.g., `[internal_review, platform_clean]` for Reels)
   - Music mode + persona band (from `manifest.music.mode` + the persona's genre/bpm/era/vocal/duration constraints)

4. **Write** `/work/$1/docs/strategy.md` — 8 to 16 sentences. Be specific
   enough another editor (or the user on return) could reconstruct your
   intent. The strategy must reference:
   - Platform + variants (from `delivery.preset` + `delivery.variants`)
   - Audience persona (from `manifest.audience_persona`) + WHY this persona
   - Brand voice (from `manifest.brand.voice`) + how it shapes pace/grade
   - Music mode + proposed direction (per the persona's genre/bpm band)
   - Shape / structural arc (HOOK→PROBLEM→SOLUTION→… or invent)
   - Take choices summary
   - Cut direction (tight / breathy / cinematic)
   - Animation plan (or "none") — gated by persona
   - Grade direction (preset or "neutral")
   - Subtitle style + language
   - Length estimate within the preset's max_duration_s
   - **One line of rationale per major decision** so the audit trail is honest.

   The strategy MUST be a continuation of `manifest.brief_intent` — it
   builds on the inferences, doesn't restate them. If a strategy
   decision contradicts a brief_intent inference, EXPLAIN why in the
   strategy and update brief_intent.

5. **Self-approve.** Set `manifest.strategy.approved = true` and
   `manifest.stage = strategy-confirmed`. Auto-commit captures it. Move
   on to edl-built (the loop will direct this on next turn).

6. **Only if the user is interactive THIS session AND has explicitly
   asked to be consulted** ("don't proceed without me", "show me before
   cutting"), present the strategy inline and wait. Otherwise: don't ask.

## What NOT to do

- Do NOT propose a strategy without reading the packed transcript +
  visual context first.
- Do NOT make any cuts, extracts, or renders here. This command stops
  at `strategy-confirmed` and hands off to edl-built.
- Do NOT assume content type from filenames. Look at the transcript +
  thumbnails.
- Do NOT block waiting for approval. Self-approve. The user audits on
  return.
- Do NOT ask "want me to proceed?" — the answer is always yes (proceed
  to the next stage), the question wastes a turn.
