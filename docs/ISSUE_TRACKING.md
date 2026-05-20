# Issue Tracking

Per-project issues live at `/work/<project-id>/docs/issues/<id>-<slug>.md`.
Each is a markdown file with YAML frontmatter + a body.

The `issue-state-review.sh` PreToolUse hook guards changes to `status:`
or `stage:` lines; flips require a fresh APPROVED verdict marker from
an in-instance reviewer sub-agent.

## Frontmatter schema

```yaml
---
id: 0042                      # zero-padded sequential
title: "Cut filler words around 0:34"
type: Cut                     # see "Issue types" below
priority: P1                  # P0 (blocker) | P1 (important) | P2 (nice-to-have)
status: Open                  # Open | Active | Blocked | Review | Closed
stage: edl-built              # matches pipeline stage ladder; see ARCHITECTURE.md
created: 2026-05-20T10:00:00Z
blocked_by: []                # list of issue IDs that must close first
references:                   # files this issue is about
  - edit/edl.json
  - edit/transcripts/take_03.json
evidence_required:
  - edit/edl.json ranges aligned to word boundaries
  - smoke-test render shows no audible click at the cut
---
```

## Issue types

| Type | When to file |
|---|---|
| **Cut** | A specific cut, splice, or trim decision |
| **Grade** | A color or exposure correction call |
| **Overlay** | An animation slot to build (one issue per slot) |
| **Audio** | EQ, normalize, fade, music-bed decision |
| **Subtitle** | Styling, chunking, or specific subtitle correction |
| **Render** | A render config decision (resolution, codec, profile) |
| **Strategy** | An overarching plan decision worth re-litigating |
| **Bug** | Something broken in the pipeline or in a skill |
| **Capability** | A capability promotion up the stage ladder (see CAPABILITY_MATRIX.md) |
| **Test** | A test/check that should be added |
| **Audit** | Going back to verify earlier work (after a Hard Rule violation, etc.) |
| **Decision** | A user-input-required call |
| **Refactor** | Cleanup that unblocks other work |
| **Epic** | Long-running container holding sub-issues |

## Status meaning

- **Open** — known, not yet in active work
- **Active** — agent (or a sub-agent) is working on it right now
- **Blocked** — waiting on another issue, on user input, or on external state
- **Review** — work done, awaiting reviewer-sub-agent approval to close
- **Closed** — verdict marker APPROVED + evidence on disk

## Stage on an issue vs stage on the project

- **Project stage** (in `manifest.json`) tracks the *current* pipeline
  step the project is at.
- **Issue stage** (in `docs/issues/*.md`) tracks the *deliverable* this
  issue is responsible for and how far it has progressed up the ladder
  defined in `CAPABILITY_MATRIX.md`.

## Body convention

After the frontmatter, three short sections (mirrors nix-zeneca style):

```markdown
## Why

One paragraph: what observable problem or goal does this issue address?

## Done when

Bulleted acceptance criteria — concrete, testable, file-pathed.

## Notes

Decisions, links to past commits, conversation excerpts. Append-only.
```

## When the agent files an issue

Whenever the loop-not-done.sh hook directs a non-trivial action — e.g.,
"build 3 animation slots in parallel" — the agent files one issue per
slot. This:

1. Gives the reviewer sub-agent a concrete acceptance contract.
2. Lets `auto-commit.sh` produce per-issue commit messages.
3. Makes the work resumable across sessions.

For trivial single-step actions (one ffprobe, one transcript dump), no
issue is needed — those are recorded in `project.md` instead.

## How the agent picks the next issue

Order matches `loop-not-done.sh`:

1. Continue any `status: Active` issue if not blocked.
2. Otherwise next issue by priority/type ladder:
   - P0 `Bug` (broken pipeline)
   - P0 `Capability` (gates failing for current stage)
   - P0 `Cut` / `Strategy` (delivery-blocking decisions)
   - P1 `*`
   - `Test`, `Audit`
   - P2 `*`

Never pick by lowest issue number alone.

## Closing an issue

1. Land the work + on-disk evidence.
2. Update the issue body's `## Notes` with a one-line completion log
   (timestamp, commit hash, what passes).
3. Edit `status: Closed` and `stage: production-ready` (or the
   relevant terminal stage for the capability).
4. The reviewer sub-agent will be invoked by `issue-state-review.sh`.
   If APPROVED, the edit lands and `auto-commit.sh` writes a commit
   like `0042 auto-commit: in-progress edits between turns`.
