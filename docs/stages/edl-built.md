# Stage: edl-built

User-approved strategy in hand. Now produce the Edit Decision List —
word-boundary-snapped ranges with beat labels.

## Entry condition

- `manifest.stage == strategy-confirmed`
- `manifest.strategy.approved == true`
- `docs/strategy.md` exists

## What to do

Spawn an **in-instance editor sub-agent** (Agent tool,
`subagent_type: general-purpose`) with a self-contained brief.
Sub-agents have no parent context — the prompt MUST include:

1. Goal sentence: "Build the EDL for project `<id>`. Return JSON only."
2. Inputs to read:
   - `/work/<id>/docs/strategy.md`
   - `/work/<id>/edit/takes_packed.md`
   - `/work/<id>/manifest.json` (for output_spec, length target)
3. Output target: `/work/<id>/edit/edl.json`
4. Format (mirrors `video-use/SKILL.md`):
   ```json
   {
     "version": 1,
     "sources": {"src_id": "/abs/path.mp4", ...},
     "ranges": [
       {"source": "src_id", "start": 2.42, "end": 6.85,
        "beat": "HOOK", "quote": "...",
        "reason": "Cleanest delivery; stops before slip at 38.46."}
     ],
     "grade": "warm_cinematic",
     "overlays": [],
     "subtitles": "edit/master.srt",
     "total_duration_s": 87.4
   }
   ```
5. Hard rules (cite explicitly in the prompt):
   - Start/end times MUST fall on word boundaries from the transcript
   - Pad cut boundaries 30–200ms (Hard Rule 7)
   - Prefer silences ≥ 400ms as cut targets
   - Snap to nearest word boundary; never cut inside a word (Hard Rule 6)
   - If over budget, revise: drop a beat or trim tails. Report total + self-correct.
6. Structural archetype (pick from strategy.md or invent):
   HOOK → PROBLEM → SOLUTION → BENEFIT → EXAMPLE → CTA (tech launch)
   INTRO → SETUP → STEPS → GOTCHAS → RECAP (tutorial)
   Q → A → FOLLOWUP × N (interview)
   ARRIVAL → HIGHLIGHTS → QUIET → DEPARTURE (travel)
   THESIS → EVIDENCE → COUNTERPOINT → CONCLUSION (documentary)
   INTRO → VERSE → CHORUS → BRIDGE → OUTRO (music)
7. Anti-list: do NOT cut mid-word; do NOT exceed total_duration target by >5%;
   do NOT include slips from `docs/pre-scan.md` unless no better take exists.
8. Deliverable checklist: write edl.json, run
   `fsh-context edl-validate <id>`, return the validation summary.
9. "Do not ask questions. Pick the most defensible interpretation."

## After the sub-agent returns

1. Read its EDL.
2. `fsh-context edl-validate <id>` → MUST exit 0.
3. `manifest.stage = edl-built`. Commit.

## Pitfalls

- **Sub-agent guesses pacing.** Pad the brief with specific cut-padding
  values from the strategy (e.g., "50ms before first kept word, 80ms
  after last").
- **Sub-agent over-budgets.** Tell it to self-correct: drop a beat or
  trim tails BEFORE returning the EDL, not in a second pass.
- **Sources map empty.** If sources map is missing, edl-validate fails.
  Include it explicitly in the deliverable checklist.

## Advance to: cuts-extracted
