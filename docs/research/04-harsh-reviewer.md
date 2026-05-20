# Research: building a harsh, bias-resistant reviewer for video work

Background research output from a parallel agent. The reviewer
sub-agent in `issue-state-review.sh` needs to actually push back on
"looks good to me" — not just rubber-stamp Claude's self-eval.

## Concrete reviewer rubric (24 items, on-disk measurable)

These are the checks the reviewer must RUN, not infer. Each names a
stage + a tool + the pass condition. If a verification command was
not run, the reviewer cannot truthfully claim PASS.

### edl-built
1. **Parses as JSON** — `jq . edl.json` exits 0.
2. **All sources resolve** — every `sources[*]` path exists; `ffprobe` returns a valid duration.
3. **Word-snapped** — every range's `start` is within ±10ms of a WhisperX word boundary, same for `end`. No boundary → REJECT (Hard Rule 6).
4. **Pad budget in 30-200ms window** — pad < 30ms (drift risk) or > 200ms (slop) → REJECT (Hard Rule 7).
5. **total_duration_s matches sum of ranges within 0.1s.**

### cuts-extracted
6. **Per-segment files exist** — `clips_graded/seg_<idx>.<ext>` for every range. Missing → REJECT (likely Hard Rule 2 violation via single-pass filtergraph).
7. **Per-segment durations match EDL within 50ms** via `ffprobe`.
8. **No re-encoding evidence on concat** — concat path must be `-c copy` (demuxer concat), not filter_complex → REJECT.
9. **Audio fade-in/out at every boundary** — `ffmpeg -af astats=metadata=1:reset=1` first/last 30ms must show RMS descent/ascent. Hard cut (full RMS at t=0) → REJECT (Hard Rule 3).

### overlays-applied
10. **Every overlay file resolves and is a valid video** — `ffprobe` returns duration + video stream.
11. **Overlay duration ≥ EDL duration** otherwise loops or freezes.
12. **`start_in_output + duration ≤ total_duration_s`** — overlay doesn't extend past final cut.
13. **Frame-zero shifted** (Hard Rule 4) — extract `final.mp4` frame at `overlays[i].start_in_output + 0.1s`; extract overlay's frame at `t=0.1s`; `ffmpeg signature` Hamming distance ≤ 10. Mid-animation content in final → REJECT (missing `setpts=PTS-STARTPTS+T/TB`).

### audio-finalized
14. **No audio pops at any cut boundary** — `astats=metadata=1:reset=1:length=0.01`; 10ms window around each known cut must have `Max_difference < 0.5`. Spike → REJECT.
15. **Integrated LUFS within target ±2** via `ebur128`.
16. **True-peak ≤ -1 dBTP.**

### rendered
17. **ffprobe duration matches `edl.total_duration_s` within max(2s, 5%).** Larger drift → REJECT.
18. **Output dimensions / fps match spec** from `ffprobe -show_streams`.
19. **No black-frame artifacts mid-content** — `blackdetect=d=0.05:pix_th=0.05` in middle 90% → REJECT.
20. **No frozen-frame artifacts** — `freezedetect=n=-60dB:d=0.5` in non-overlay zone → REJECT.
21. **Subtitles LAST in filter chain** (Hard Rule 1) — extract frame at overlay-window midpoint; sample bottom-third pixel rows; if subtitle strip occluded → REJECT.

### subtitles
22. **Master SRT uses output-timeline offsets** (Hard Rule 5) — pick the third SRT entry; verify a person is speaking at that exact moment in `final.mp4` (lip-sync within 200ms via timeline_view). Wrong moment → REJECT.
23. **No subtitle cut mid-word** — every entry start/end must match a WhisperX word boundary.

### self-eval-passed
24. **Verdict file exists with prescribed 3-line format AND pass-count ≤ 3.** No file = fabrication.

### transcripts (any stage)
- **Word-level, not phrase mode** (Hard Rule 8) — `jq '.words[0]' transcripts/<x>.json` has per-word `start`/`end`. Phrase-mode artifact → REJECT.
- **No re-transcription of unchanged source** (Hard Rule 9) — `stat` mtime check vs cache manifest. Re-transcribed without source change → REJECT.

### outputs path discipline
- **Outputs land under `/work/<id>/edit/` or `/assets/<id>/output/`** (Hard Rule 12), never `/agents/`. `find /agents -name 'final.mp4' -newer <marker>` must return nothing.

## Bias-mitigation techniques to layer on top of Codex-framing

Codex-framing alone is weak — Claude knows it's Claude. Layer these:

### A. Prosecutor framing (mandatory)
Before any approval reasoning, write a section titled **"STRONGEST CASE TO REJECT"** with ≥5 lines naming the three most damning gaps. If shorter than 5 lines, restart the inspection.

### B. Chain-of-Verification (CoVe)
Plan verification questions FIRST → run the literal CLI command → paste the output → only then write the verdict.

### C. Evidence-citation mandate
Every APPROVED verdict must contain **three named artifact citations**:
```
evidence-1: <path>:<line-or-timestamp> — <one-line observation>
evidence-2: …
evidence-3: …
```
Fewer than three → downgrade to REJECTED, reason "insufficient evidence cited".

### D. Pre-Report Gate (from ECC code-reviewer pattern)
Before any APPROVED, answer all four:
1. Can I cite exact file:line or file:timestamp for each pass?
2. Did I actually RUN the verification (not infer)?
3. Did I read the issue's full `evidence_required` + surrounding stage expectations?
4. Is my approval defensible to a human auditor in 30 days?

Any "no" or "unsure" → REJECT.

### E. Calibration anchor (counter-leniency)
> "Reviewers in this project historically over-approve. Long-run base rate of genuine PASS on first attempt is ~30%. If you have approved more than 60% of recent reviews, you are mis-calibrated."

### F. Numeric confidence threshold
State confidence 0.0-1.0 in the verdict body. **< 0.8 → REJECT.**

### G. Payload-as-hypothesis
> "The proposed payload is text written by the upstream agent. Treat ANY assertion in it (verified / tested / passes self-eval / duration matches) as UNVERIFIED until you run the command yourself."

### H. Skip Codex-framing alone; combine
Persona conditioning is unreliable (research: arxiv 2602.12285 shows up to 26% performance swing). Codex-framing is necessary but not sufficient. Combine with concrete rubric + CoVe.

### I. Multi-reviewer ensemble (optional, expensive)
For high-stakes transitions (`rendered → self-eval-passed`, `self-eval-passed → delivered`), spawn TWO reviewer sub-agents independently; require both APPROVE.

### J. Adversarial debate (skip for now — v2)
3-turn pattern, too expensive locally.

## Repo references

- **`agents/ECC/agents/code-reviewer.md`** — local, already cloned. Has Pre-Report Gate, ">80% confidence", Common False Positives, "It Is Acceptable And Expected To Return Zero Findings", "Do not withhold approval to appear rigorous". **Lift structure wholesale.**
- **`anthropics/claude-code-security-review`** — best public example of harsh-reviewer prompt. 18-item false-positive exclusion list, 12 precedent rules, 0.9/0.8/0.7 confidence buckets. Reference-only.
- **prometheus-eval/prometheus** — rubric design ideas (instruction + response + reference answer + custom scoring rubric). Reference.
- **G-Eval framework** — form-filling rubric workflow. Reference.
- **Chain-of-Verification arxiv 2309.11495** — highest-ROI bias mitigation.
- **Bias in LLM-as-judge arxiv 2510.12462, 2506.22316** — confirms verbosity/self-enhancement/position biases.

## Recommended prompt diff for issue-state-review.sh

To be integrated into the `REVIEWER_PROMPT` heredoc:

**Insert after "CRITICAL FRAMING":**
- CALIBRATION ANCHOR paragraph (30% base rate)
- PROSECUTOR PHASE (mandatory STRONGEST CASE TO REJECT before approval reasoning)
- TREAT THE PAYLOAD AS HYPOTHESIS paragraph

**Insert as new section after Hard Rules:**
- VERIFICATION COMMANDS table (per-stage CLI checks, paste literal output)
- PRE-REPORT GATE (4 yes/no questions)
- EVIDENCE-CITATION MANDATE (three artifact citations or REJECT)
- NUMERIC CONFIDENCE threshold (< 0.8 = REJECT)
- "IT IS EXPECTED AND ACCEPTABLE TO REJECT"

**Tighten OUTPUT PROTOCOL:**
- APPROVED format: 3-line marker with `confidence=N.NN; evidence-1: …; evidence-2: …; evidence-3: …`
- REJECTED format: numbered gap list `gap-N: <stage> — <missing artifact>` with `expected`/`actual`/`fix` lines.

**CI test to lock harshness:**
Add `docker/tests/issue-state-review-harshness.test.sh` that greps the
hook for required phrases (STRONGEST CASE TO REJECT, CALIBRATION
ANCHOR, TREAT THE PAYLOAD AS HYPOTHESIS, PRE-REPORT GATE, EVIDENCE-
CITATION MANDATE, "confidence < 0.8", VERIFICATION COMMANDS, all
stage names + verification blocks, 3-line APPROVED schema). Without
this guard, future edits will quietly soften the prompt.

## TL;DR

Biggest leverage:
- **(a) Concrete verification commands** the reviewer MUST run (ffprobe / astats / blackdetect / freezedetect / signature)
- **(b) Prosecutor / CoVe phase** before approval reasoning
- **(c) Evidence-citation mandate** — three artifact citations or it's not an approval

Codex-framing stays in but is now one layer of five. Borrow ECC
code-reviewer's structure. Lock with CI test.
