# Stage: strategy-confirmed

Propose a 4–8 sentence edit plan in plain English. **Wait for user
approval before any cut is made.** (Hard Rule 11.)

## Entry condition

- `manifest.stage == inventoried`
- `edit/takes_packed.md` exists
- `manifest.inputs[]` populated

## What to do

1. **Read inputs**:
   - `edit/takes_packed.md`
   - `/assets/<id>/prompt.txt` if present
   - `docs/pre-scan.md` from the inventoried stage
   - Sample `timeline-view` PNGs on 1–2 sources for visual context

2. **Ask sharp, content-shaped questions.** Not a fixed checklist —
   the right questions depend on the material. Collect only what
   matters:
   - Content type (talking head / interview / montage / tutorial / travel / event)
   - Target length and aspect (1920x1080@30, 1080x1920@30, 1920x1080@24, etc.)
   - Aesthetic direction (cinematic / energetic / neutral)
   - Must-preserve moments
   - Must-cut moments
   - Animation needs (none / lower thirds / kinetic typography / data viz)
   - Subtitle preference (style, chunking, case)
   - Color grade preference
   - Delivery format (MP4 + NLE XML by default)

3. **Write `docs/strategy.md`** — 4 to 8 sentences:
   - Shape / structural arc (HOOK→PROBLEM→SOLUTION→… or invent)
   - Take choices summary
   - Cut direction (tight / breathy / cinematic)
   - Animation plan (or "none")
   - Grade direction (preset or "neutral")
   - Subtitle style
   - Length estimate

4. **Present to the user inline.** Ask them to approve, refine, or reject.

5. On approval:
   - Set `manifest.strategy.approved = true`
   - Set `manifest.stage = strategy-confirmed`
   - The reviewer-sub-agent does NOT gate this — `manifest.stage` is
     operational state, not an issue file. Commit.

6. On refinement: rewrite `docs/strategy.md` and loop. Each iteration
   appends a new section, not a rewrite, so the conversation is
   auditable.

7. On rejection: write the gaps to `docs/strategy-gaps.md` and stop.
   Do NOT advance.

## Advance to: edl-built

Spawn the editor sub-agent.

## Pitfalls

- **Don't propose without reading the packed transcript.** Strategy must
  be grounded in actual content, not filename guesses.
- **Don't make cuts before approval.** Hard Rule 11.
- **Don't infer content type from filenames** (e.g., "wedding.mp4" — the
  transcript might reveal it's a corporate event).
- **One AskUserQuestion at a time.** Don't dump a 6-question wall;
  shape questions to what the material implies.
