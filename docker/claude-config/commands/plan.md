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
   `inventoried`. If not, run `/inventory $1` first.

2. **Read** the inputs:
   - `/work/$1/edit/takes_packed.md`
   - `/assets/$1/prompt.txt` if present (else the user's chat-level prompt)
   - Any previous `/work/$1/project.md` session notes
   - Sample `timeline-view` PNGs on 1-2 sources for visual context
   - Thumbnail contact sheet if one was generated in inventoried stage

3. **Decide the answers yourself** (don't ask). Pick:
   - Content type (talking head / interview / montage / tutorial / travel / event / corporate / wedding / doc / etc.)
   - Target length and aspect ratio (infer from source orientation, prompt context)
   - Aesthetic direction (cinematic / energetic / neutral / brand-aligned)
   - Must-preserve moments (from transcript + thumbnails)
   - Must-cut moments (slips, redundant takes, off-thesis material)
   - Animation overlays (none / lower-thirds / kinetic typography / data viz / motion graphics)
   - Subtitle preference (style, chunking, case, or "none" for non-dialogue work)
   - Color grade preference (preset name or "neutral")
   - Delivery format (default: MP4 + NLE XML; vertical if source is portrait)

4. **Write** `/work/$1/docs/strategy.md` — 6 to 12 sentences. Be specific
   enough another editor (or the user on return) could reconstruct your
   intent: shape, structural arc, take choices, cut direction, animation
   plan, grade direction, subtitle style, length estimate. **One line of
   rationale per major decision** so the audit trail is honest.

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
