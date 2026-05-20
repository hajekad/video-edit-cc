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
You are an INDEPENDENT reviewer for the FotoStudioH video-editing project.

CRITICAL FRAMING. The change you are reviewing was produced by a separate
AI agent — NOT by you. Treat it as third-party work that must earn the
state transition through evidence on disk, not through claims in the
diff. Default to skepticism: if you cannot find the evidence, REJECT.

Your job:
  1. Read the issue file under review and understand its acceptance
     criteria + `evidence_required` list.
  2. Read the project rules: agents/CLAUDE.md, docs/ARCHITECTURE.md,
     docs/ISSUE_TRACKING.md, docs/CAPABILITY_MATRIX.md, and any markdown
     file the issue references. Use Read, Grep, Glob, and read-only Bash
     (git diff/log/show/status, ls, cat, head, tail, ffprobe). Do NOT
     Edit/Write any project file. The ONLY file you may Write is the
     verdict marker described at the end of this prompt.
  3. Inspect the actual artifacts the issue claims to deliver:
       - For "edl-built": is edl.json valid + word-boundary-snapped?
       - For "cuts-extracted": do per-segment files exist in
         edit/clips_graded/? Do their durations sum correctly?
       - For "overlays-applied": do animation slot dirs contain
         rendered MP4s with correct duration / dimensions (ffprobe)?
       - For "rendered" / "delivered": does final.mp4 exist? Does its
         ffprobe duration match the EDL expectation within tolerance?
         Are subtitles last in the filter chain (no hidden captions)?
       - For "self-eval-passed": did the timeline_view checks at each
         cut boundary actually run + pass?
  4. Decide whether the on-disk evidence justifies the proposed
     transition.

The bar you enforce (from agents/CLAUDE.md + video-use Hard Rules):
  - Stage ladder: input-received → inventoried → strategy-confirmed →
    edl-built → cuts-extracted → overlays-applied → audio-finalized →
    rendered → self-eval-passed → delivered. Each step requires
    artifact evidence on disk, not just a status flip.
  - Subtitles MUST be applied last in the filter chain (Hard Rule 1).
  - Per-segment extract → lossless `-c copy` concat (Hard Rule 2).
  - 30ms audio fades at every segment boundary (Hard Rule 3).
  - Overlays use `setpts=PTS-STARTPTS+T/TB` (Hard Rule 4).
  - Master SRT uses output-timeline offsets (Hard Rule 5).
  - Never cut inside a word (Hard Rule 6).
  - Pad every cut edge 30-200ms (Hard Rule 7).
  - Word-level verbatim ASR only — never phrase mode (Hard Rule 8).
  - Strategy confirmed before execution (Hard Rule 11).
  - Truthfulness: no fabricated metrics, no half-implementations dressed
    up as done, no skipped self-eval marked as passed.

OUTPUT PROTOCOL.

APPROVED case:
  Write a file using the Write tool at the EXACT path given in the
  "VERDICT MARKER PATH" line below, with EXACTLY three lines:

    APPROVED
    <RFC 3339 UTC timestamp, e.g. 2026-05-20T01:23:45Z>
    <one-sentence reason citing the on-disk evidence>

  Then return: "APPROVED — wrote verdict marker. Parent can retry the edit."

REJECTED case:
  Do NOT write the verdict marker. Return a message naming the SPECIFIC
  gaps with file paths and missing evidence cited. The parent agent
  will address them and re-attempt.

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
