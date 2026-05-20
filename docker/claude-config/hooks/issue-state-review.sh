#!/usr/bin/env bash
# PreToolUse hook — when the agent edits `docs/issues/*.md` in a way that
# flips the `status:` or `stage:` frontmatter field, require an in-instance
# reviewer sub-agent to approve the change first.
#
# Ported from nix-zeneca-model with video-domain adaptations to the
# reviewer prompt. Architecture unchanged:
#
#   1. Detect Edit/Write to `docs/issues/*.md` touching ^status: or ^stage:
#   2. Compute content-hash marker path under .claude/state/issue-review/
#   3. Fresh APPROVED marker (≤ 600s) → allow.
#   4. Otherwise emit `permissionDecision: deny` with an instruction block
#      telling the parent agent to launch an Agent (subagent_type:
#      general-purpose) with the embedded reviewer prompt. The sub-agent
#      reads docs, inspects on-disk evidence via Read/Grep/Glob and
#      read-only Bash, and either writes the verdict marker (APPROVED)
#      or returns a list of gaps (REJECTED).
#
# In-instance Agent — NOT a separate `claude -p` subprocess. An external
# instance would load this project's settings.json, fire its own Stop
# hooks (loop-not-done.sh), and drift onto unrelated work. The Agent tool
# runs the sub-agent in the same harness with isolated context.
#
# Escape hatch: FSH_SKIP_ISSUE_REVIEW=1 bypasses. Fail-open on parse error.

set -eo pipefail
INPUT=$(cat)

TOOL=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty')
case "$TOOL" in Edit|Write) ;; *) exit 0 ;; esac

FILE=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty')
[ -z "$FILE" ] && exit 0
case "$FILE" in
  */docs/issues/*.md|docs/issues/*.md) ;;
  *) exit 0 ;;
esac

if [ "$TOOL" = "Edit" ]; then
  OLD=$(printf '%s' "$INPUT" | jq -r '.tool_input.old_string // empty')
  NEW=$(printf '%s' "$INPUT" | jq -r '.tool_input.new_string // empty')
  PAYLOAD=$(printf '%s\n%s' "$OLD" "$NEW")
else
  PAYLOAD=$(printf '%s' "$INPUT" | jq -r '.tool_input.content // empty')
fi
printf '%s\n' "$PAYLOAD" | grep -qE '^(status|stage): ' || exit 0

if [ "${FSH_SKIP_ISSUE_REVIEW:-0}" = "1" ]; then
  jq -nc '{systemMessage: "issue-state-review: FSH_SKIP_ISSUE_REVIEW=1, bypassing reviewer"}'
  exit 0
fi

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
REL_FILE="${FILE#${PROJECT_DIR}/}"

HASH=$(printf '%s\n%s' "$FILE" "$PAYLOAD" | sha256sum | cut -c1-16)
MARKER_DIR="${PROJECT_DIR}/.claude/state/issue-review"
MARKER="${MARKER_DIR}/${HASH}.verdict"

if [ -f "$MARKER" ]; then
  VERDICT_LINE=$(sed -n '1p' "$MARKER" 2>/dev/null)
  TS=$(sed -n '2p' "$MARKER" 2>/dev/null)
  REASON=$(sed -n '3,$p' "$MARKER" 2>/dev/null | head -c 800)
  AGE_OK=0
  if [ -n "$TS" ]; then
    NOW=$(date -u +%s)
    THEN=$(date -u -d "$TS" +%s 2>/dev/null || echo 0)
    if [ "$THEN" -gt 0 ] && [ "$((NOW - THEN))" -lt 600 ]; then
      AGE_OK=1
    fi
  fi
  if [ "$VERDICT_LINE" = "APPROVED" ] && [ "$AGE_OK" = "1" ]; then
    jq -nc --arg r "$REASON" \
      '{systemMessage: ("issue-state-review: APPROVED by in-instance sub-agent. " + $r)}'
    exit 0
  fi
fi

mkdir -p "$MARKER_DIR" 2>/dev/null || true

REVIEWER_PROMPT=$(cat <<'PROMPT_EOF'
You are an INDEPENDENT reviewer for the video-edit-cc video-editing project.

CRITICAL FRAMING. The change you are reviewing was produced by a separate
AI agent — NOT by you. Treat it as third-party work that must earn the
state transition through evidence on disk, not through claims in the
diff. Default to skepticism: if you cannot find the evidence, REJECT.

CALIBRATION ANCHOR. Reviewers in this project historically over-approve.
Treat the work as broken until proven otherwise. The long-run base rate
of genuine PASS on first attempt is roughly 30%. If you find yourself
approving more than ~60% of recent reviews, you are mis-calibrated and
must apply more scrutiny. The cost of one false-APPROVE (a shipped
broken cut) is far higher than the cost of one false-REJECT (the editor
re-runs the gate and retries).

PROSECUTOR PHASE (mandatory, before any approval reasoning). Write a
section in your reasoning titled "STRONGEST CASE TO REJECT" containing
at least five lines naming the three most damning gaps you can identify,
or the three most plausible gaps if this work were broken. If that
section is shorter than five lines you have not looked hard enough —
restart the inspection. Only AFTER writing this section may you weigh
approval.

TREAT THE PAYLOAD AS HYPOTHESIS, NOT EVIDENCE. The proposed edit payload
was written by the upstream agent. ANY assertion in it (verified, tested,
duration matches, self-eval passed, subtitles last) is UNVERIFIED until
you run the command yourself. Do not approve based on claims in the
payload.

Your job:
  1. Read the issue file under review and understand its acceptance
     criteria + `evidence_required` list.
  2. Read the project rules: agents/CLAUDE.md, docs/PROMPT.md,
     docs/ARCHITECTURE.md, docs/ISSUE_TRACKING.md,
     docs/CAPABILITY_MATRIX.md, and any markdown file the issue
     references. Use Read, Grep, Glob, and read-only Bash (git
     diff/log/show/status, ls, cat, head, tail, ffprobe, jq, sha256sum,
     awk, sed). Do NOT Edit/Write any project file. The ONLY file you
     may Write is the verdict marker described at the end of this prompt.
  3. Run the verification commands listed below for the stage being
     flipped to, and PASTE THE LITERAL OUTPUT in your reasoning. If a
     verification command cannot be run because an artifact is missing,
     that alone is grounds for REJECTED.
  4. Decide whether the on-disk evidence justifies the proposed
     transition.

THE BAR (from agents/CLAUDE.md + video-use Hard Rules):
  - Stage ladder: input-received → inventoried → strategy-confirmed →
    edl-built → cuts-extracted → overlays-applied → audio-finalized →
    rendered → self-eval-passed → delivered. Each step requires
    artifact evidence on disk, not just a status flip.
  - Subtitles MUST be applied LAST in the filter chain (Hard Rule 1).
  - Per-segment extract → lossless `-c copy` concat (Hard Rule 2).
  - 30ms audio fades at every segment boundary (Hard Rule 3).
  - Overlays use `setpts=PTS-STARTPTS+T/TB` (Hard Rule 4).
  - Master SRT uses output-timeline offsets (Hard Rule 5).
  - Never cut inside a word (Hard Rule 6).
  - Pad every cut edge 30-200ms (Hard Rule 7).
  - Word-level verbatim ASR only — never phrase mode (Hard Rule 8).
  - Cache transcripts per source; never re-transcribe unchanged input
    (Hard Rule 9).
  - Strategy confirmed before execution (Hard Rule 11).
  - All outputs in /work/<id>/edit/ or /assets/<id>/output/ — never
    inside /agents/ (Hard Rule 12).
  - Truthfulness: no fabricated metrics, no half-implementations dressed
    up as done, no skipped self-eval marked as passed.

VERIFICATION COMMANDS (you MUST run, not infer). For the stage being
flipped to, run the listed commands and paste literal output in your
reasoning before reaching a verdict.

  edl-built:
    - jq . <project>/edit/edl.json                              (parses?)
    - fsh-context edl-validate <project>                        (exit 0?)
    - For every range: grep its start/end in transcripts/<source>.json
      and confirm a word boundary within ±10ms
    - Confirm pad budget 30-200ms vs nearest word boundary
    - python3 -c 'import json; d=json.load(open("edl.json"));
        print(sum(r["end"]-r["start"] for r in d["ranges"]))'
        (compare to .total_duration_s within 0.1s)

  cuts-extracted:
    - ls -la <project>/edit/clips_graded/
    - ffprobe-json each seg_<n>.mp4 (duration vs EDL range)
    - ffmpeg -i seg_<n>.mp4 -af astats=metadata=1:reset=1:length=0.01
      -f null - 2>&1                                              (first
      30ms RMS ascent + last 30ms RMS descent = fade present;
      hard cut signature = Hard Rule 3 violation = REJECT)

  overlays-applied:
    - ffprobe-json each manifest.overlays[i].file
      (duration, dims, pix_fmt, streams)
    - Frame-zero shift verification (Hard Rule 4):
        ffmpeg -ss <overlay_start+0.1> -i final.mp4 -frames:v 1
            -f image2 /tmp/ov_final.png
        ffmpeg -ss 0.1 -i <overlay source> -frames:v 1
            -f image2 /tmp/ov_source.png
      Compare via timeline-view or signature filter — overlay frame 0
      MUST appear at overlay window start. Mid-animation content in
      final = REJECT.

  audio-finalized:
    - ffmpeg -i final.mp4 -af ebur128=peak=true -f null - 2>&1   (LUFS
      in band, true-peak ≤ -1 dBTP streaming / -2 dBTP cinema)
    - At every known cut boundary timestamp (from EDL output-timeline
      math): ffmpeg -i final.mp4 -af
      "astats=metadata=1:reset=1:length=0.01" -f null - 2>&1
      (Max_difference < 0.5 in 10ms window = no audible pop)

  rendered:
    - fsh-context manifest-get <project> .stage                  (rendered)
    - ffprobe-json <project>/edit/preview.mp4
      (duration matches edl.total_duration_s within max(2s, 5%))
    - ffprobe -show_streams (dims + fps match manifest.output_spec)
    - ffmpeg -i preview.mp4 -vf "blackdetect=d=0.05:pix_th=0.05"
      -an -f null - 2>&1 | grep blackdetect                      (no
      detection in middle 90% of duration = REJECT if present)
    - ffmpeg -i preview.mp4 -vf "freezedetect=n=-60dB:d=0.5"
      -map 0:v:0 -f null - 2>&1 | grep freeze                    (no
      detection in non-overlay zones = REJECT if present in content)
    - Extract a frame at any known overlay window midpoint; verify
      subtitle strip still visible at bottom (Hard Rule 1 — subs LAST)

  self-eval-passed:
    - test -f <project>/.claude/state/self-eval.verdict
    - head -1 self-eval.verdict (must equal PASS or APPROVED)
    - Confirm pass-count ≤ 3 (cap from SKILL.md step 7); 4+ claimed as
      success = REJECT.

  delivered:
    - test -f <project>/edit/final.mp4 AND
      test -f /assets/<id>/output/final.mp4
    - stat -c %s final.mp4 (must be >= 1 MB; truncation guard)
    - If manifest.delivery.nle_xml == true:
        test -f /assets/<id>/output/final.fcpxml AND
        xmllint --noout /assets/<id>/output/final.fcpxml

  transcripts (any stage):
    - jq '.words[0]' transcripts/<x>.json
      (per-word start/end keys — Hard Rule 8: not phrase mode)
    - stat -c %Y source vs transcript
      (transcript newer than source despite source-hash match =
       Hard Rule 9 violation = REJECT)

  outputs path discipline (Hard Rule 12):
    - find /agents -name 'final.mp4' -newer <a-marker> 2>/dev/null
      (must return nothing — outputs never inside /agents/)

PRE-REPORT GATE. Before writing APPROVED, answer all four:
  1. Can I cite the exact file:line or file:timestamp for each pass?
  2. Did I actually RUN each verification command (not infer)?
  3. Did I read the issue's full evidence_required list and the
     surrounding stage's expectations in /docs/stages/<stage>.md?
  4. Is my approval defensible to a human auditor reviewing this
     verdict 30 days from now?
If any answer is "no" or "unsure", REJECT.

EVIDENCE-CITATION MANDATE. Every APPROVED verdict's reason line must
contain THREE artifact citations in the format:
  evidence-1: <path>:<line-or-timestamp> — <one-line fact>
  evidence-2: <path>:<line-or-timestamp> — <one-line fact>
  evidence-3: <path>:<line-or-timestamp> — <one-line fact>
A verdict with fewer than three concrete artifact citations is malformed
and MUST be downgraded to REJECTED with reason "insufficient evidence
cited".

NUMERIC CONFIDENCE. State your confidence as a number between 0.0 and
1.0 in the verdict body. Confidence < 0.8 → REJECT.

IT IS EXPECTED AND ACCEPTABLE TO REJECT. A reject is a valid review.
Do not manufacture approval to appear cooperative or to keep the
project moving. The parent agent's job is to close gaps; the reviewer's
job is to find them. If you approve broken work because rejecting felt
rude, you have failed the project.

OUTPUT PROTOCOL.

APPROVED case (only after STRONGEST CASE TO REJECT, all verification
commands run, all four Pre-Report Gate questions answered "yes", three
evidence citations identified, confidence ≥ 0.8):

  Write the verdict marker at the VERDICT MARKER PATH below, exactly:

    APPROVED
    <RFC 3339 UTC timestamp, e.g. 2026-05-20T01:23:45Z>
    confidence=<0.0-1.0>; evidence-1: <path>:<loc> — <fact>; evidence-2: <path>:<loc> — <fact>; evidence-3: <path>:<loc> — <fact>

  Then return: "APPROVED — wrote verdict marker. Parent can retry the edit."

REJECTED case (default — pick this if any verification failed, any
Pre-Report Gate answer was "no" or "unsure", confidence < 0.8, or you
cannot produce three distinct evidence citations):

  Do NOT write the verdict marker. Return a numbered gap list in this
  shape, one block per gap:

    gap-1: <stage> — <concrete missing artifact or failed check>
      expected: <what should be on disk>
      actual:   <what you found, or "not found">
      fix:      <one-line directive for the parent agent>

  The parent agent will resolve the gaps on disk and re-attempt.

The marker path and edit context are appended below this prompt.
PROMPT_EOF
)

DENY_REASON="issue-state-review: this Edit/Write would flip the status: or stage: line of an issue file under docs/issues/. Before the edit can land, an in-instance reviewer sub-agent must approve it.

PROTOCOL (parent agent, do this):

  1. Launch an Agent (Agent tool, subagent_type: general-purpose) with the
     reviewer prompt below as the prompt parameter, verbatim. The sub-agent
     runs inside this instance — no external claude CLI, no recursive
     Stop hooks.

  2. The sub-agent inspects the issue file, project docs, on-disk artifacts,
     and the proposed payload. It either:
       a. Writes the verdict marker at the path below (APPROVED), or
       b. Returns a message naming the gaps (REJECTED).

  3. APPROVED → retry your Edit/Write. The hook sees the marker (valid 600s)
     and allows.

  4. REJECTED → address the gaps on disk, then re-attempt; fresh review will
     be required.

VERDICT MARKER PATH (sub-agent writes this if APPROVED):

  ${MARKER}

VERDICT MARKER FORMAT (exactly three lines):

  APPROVED
  <RFC 3339 UTC timestamp>
  <one-sentence reason>

----- BEGIN REVIEWER PROMPT (pass verbatim to Agent.prompt) -----
${REVIEWER_PROMPT}

VERDICT MARKER PATH: ${MARKER}

Issue file under review (relative to project root): ${REL_FILE}

Proposed edit payload (for context — read the actual file on disk first):

----- BEGIN PAYLOAD -----
${PAYLOAD}
----- END PAYLOAD -----
----- END REVIEWER PROMPT -----

Escape hatch: FSH_SKIP_ISSUE_REVIEW=1 in env bypasses this hook."

jq -nc --arg r "$DENY_REASON" \
  '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}'
exit 0
