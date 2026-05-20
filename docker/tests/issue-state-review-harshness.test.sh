#!/usr/bin/env bash
# CI guard for docker/claude-config/hooks/issue-state-review.sh.
#
# The reviewer prompt embeds anti-bias clauses (calibration anchor,
# prosecutor phase, evidence-citation mandate, etc.) that are easy to
# accidentally soften during routine edits. This test fails if any
# required harshness clause goes missing, so a regression is caught
# at PR review time instead of in production.
#
# Run from anywhere:
#   bash docker/tests/issue-state-review-harshness.test.sh
#
# Exit 0 = all clauses present. Exit 1 = one or more missing.

set -u

HOOK="${HOOK:-$(cd "$(dirname "$0")/.." && pwd)/claude-config/hooks/issue-state-review.sh}"

if [ ! -f "$HOOK" ]; then
  echo "FAIL: hook not found at $HOOK" >&2
  exit 1
fi

# Each entry: a label + a literal pattern that MUST be present in the hook.
# Patterns are matched as fixed-strings (grep -F) to dodge regex traps.
clauses=(
  "CRITICAL FRAMING"
  "CALIBRATION ANCHOR"
  "STRONGEST CASE TO REJECT"
  "PROSECUTOR PHASE"
  "TREAT THE PAYLOAD AS HYPOTHESIS"
  "VERIFICATION COMMANDS"
  "PRE-REPORT GATE"
  "EVIDENCE-CITATION MANDATE"
  "NUMERIC CONFIDENCE"
  "EXPECTED AND ACCEPTABLE TO REJECT"
  "edl-built:"
  "cuts-extracted:"
  "overlays-applied:"
  "audio-finalized:"
  "rendered:"
  "self-eval-passed:"
  "delivered:"
  "transcripts (any stage):"
  "outputs path discipline (Hard Rule 12):"
  "Confidence < 0.8 → REJECT"
  "evidence-1: <path>:<loc>"
  "evidence-2: <path>:<loc>"
  "evidence-3: <path>:<loc>"
  "gap-1: <stage>"
  "OUTPUT PROTOCOL."
  "Hard Rule 1"
  "Hard Rule 2"
  "Hard Rule 3"
  "Hard Rule 4"
  "Hard Rule 5"
  "Hard Rule 6"
  "Hard Rule 7"
  "Hard Rule 8"
  "Hard Rule 9"
  "Hard Rule 11"
  "Hard Rule 12"
)

missing=0
for clause in "${clauses[@]}"; do
  if ! grep -qF -- "$clause" "$HOOK"; then
    printf 'MISSING harshness clause: %s\n' "$clause" >&2
    missing=$((missing+1))
  fi
done

if [ "$missing" -gt 0 ]; then
  printf '\nFAIL: %d clause(s) missing from %s\n' "$missing" "$HOOK" >&2
  printf 'Restore from docs/research/04-harsh-reviewer.md before committing.\n' >&2
  exit 1
fi

printf 'PASS: all %d harshness clauses present in %s\n' "${#clauses[@]}" "$HOOK"
exit 0
