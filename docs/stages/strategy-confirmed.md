# Stage: strategy-confirmed

Propose a 4–8 sentence edit plan in plain English, write it to
`docs/strategy.md`, and self-approve. The user is an engineer running
the system — they do not approve cuts. They audit `strategy.md` on
return and intervene then if they disagree. (Hard Rule 11 — updated.)

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

2. **Decide the answers yourself** (don't ask the user — they're not the
   editor). Pick:
   - Content type (talking head / interview / montage / tutorial / travel / event)
   - Target length and aspect (1920x1080@30, 1080x1920@30, 1920x1080@24, etc. — infer from source orientation + the user's prompt)
   - Aesthetic direction (cinematic / energetic / neutral)
   - Must-preserve moments (from the transcript + thumbnails)
   - Must-cut moments (slips, redundant takes)
   - Animation needs (none / lower thirds / kinetic typography / data viz)
   - Subtitle preference (style, chunking, case)
   - Color grade preference
   - Delivery format (MP4 + NLE XML by default)

3. **Write `docs/strategy.md`** — 6 to 12 sentences. Be specific enough
   that another editor (or the user on return) could reconstruct your
   intent:
   - Shape / structural arc (HOOK→PROBLEM→SOLUTION→… or invent)
   - Take choices summary
   - Cut direction (tight / breathy / cinematic)
   - Animation plan (or "none")
   - Grade direction (preset or "neutral")
   - Subtitle style
   - Length estimate
   - Why each choice — one line of rationale per decision

4. **Self-approve.** Set `manifest.strategy.approved = true` and
   `manifest.stage = strategy-confirmed`. Commit. The reviewer-sub-agent
   does NOT gate this (`manifest.stage` is operational state, not an
   issue file).

5. **Only if the user is interactive in this session AND has explicitly
   asked to be consulted** ("don't proceed without me", "ask before
   cutting"), present the strategy inline and wait. Otherwise: keep
   moving.

6. The user audits `docs/strategy.md` on return. If they disagree, they
   edit the manifest back to `inventoried` and the pipeline re-walks
   from there.

## Advance to: edl-built

Spawn the editor sub-agent.

## Pitfalls

- **Don't propose without reading the packed transcript + thumbnails.**
  Strategy must be grounded in actual content, not filename guesses.
- **Don't ask the user to approve cuts.** They're an engineer running
  the system, not the editor. Self-approve and proceed. They audit on
  return.
- **Don't block waiting for input.** "Want me to proceed?" "Should I
  cut this?" — both are wrong. Pick the most defensible interpretation
  and go. The user can always roll back.
- **Don't infer content type from filenames** (e.g., "wedding.mp4" — the
  transcript might reveal it's a corporate event).
