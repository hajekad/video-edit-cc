---
description: Propose a 4-8 sentence edit strategy and wait for user confirmation.
argument-hint: <project-name>
---

# /plan — strategy proposal

Read the packed transcript + user prompt, propose a strategy in plain
English, and **wait for explicit user confirmation** before any cuts.

## What to do

1. **cd** into `/work/$1/`. Confirm `manifest.stage` is at least
   `inventoried`. If not, run `/inventory $1` first.

2. **Read** the inputs:
   - `/work/$1/edit/takes_packed.md`
   - `/assets/$1/prompt.txt` if present
   - Any previous `/work/$1/project.md` session notes
   - Sample `timeline_view` PNGs on 1-2 sources for visual context

3. **Ask sharp, content-shaped questions.** Not a fixed checklist.
   Collect (only what the material requires):
   - Content type (talking head / interview / montage / tutorial /
     travel / event)
   - Target length and aspect ratio (1920x1080@30, 1080x1920@30,
     1920x1080@24 cinematic, etc.)
   - Aesthetic direction (cinematic / energetic / neutral)
   - Must-preserve moments
   - Must-cut moments
   - Animation overlays needed (none / lower-thirds / kinetic typography
     / data viz / motion graphics)
   - Subtitle preference (style, chunking, case)
   - Color grade preference
   - Delivery format (default: MP4 + NLE XML)

4. **Write** `/work/$1/docs/strategy.md` — 4 to 8 sentences. Shape,
   structural arc (HOOK→PROBLEM→SOLUTION→… or whatever fits), take
   choices, cut direction, animation plan, grade direction, subtitle
   style, length estimate.

5. **Present the strategy to the user inline.** Ask them to either
   approve, refine, or reject.

6. On approval: set `manifest.strategy.approved = true` and
   `manifest.stage = strategy-confirmed`. Commit.

7. On refinement: rewrite `docs/strategy.md`, present again. Loop.

8. On rejection: ask what's wrong, write the gap to
   `docs/strategy-gaps.md`, and stop. Do NOT advance the stage.

## What NOT to do

- Do NOT propose a strategy without reading the packed transcript first.
- Do NOT make any cuts, extracts, or renders here. This command stops at
  `strategy-confirmed`.
- Do NOT assume content type from filenames. Look at the transcript.
