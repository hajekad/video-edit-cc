---
description: Multi-project job queue. Add, list, or advance.
argument-hint: <add|list|next> [args]
---

# /queue — multi-project queue

Markdown-based queue at `/work/.queue/jobs.md`. Append-only log; status
flips written inline as the agent processes jobs.

## Subcommands

### `/queue add <project-name> [prompt]`

Append to `/work/.queue/jobs.md`:
```markdown
- [ ] <project-name> queued <RFC3339> — <prompt or "no-prompt">
```

### `/queue list`

Print the queue with status indicators (`- [ ]` pending, `- [x]` done,
`- [-]` in-progress, `- [!]` blocked).

### `/queue next`

1. Find the first `- [ ]` line in `jobs.md`.
2. Flip it to `- [-]` (in-progress) with a timestamp.
3. Run `/edit <project-name>` for that job.
4. The Stop hook chain drives the rest; when project hits `delivered`,
   the agent updates the line to `- [x]`.

## Where jobs come from

User adds them with `/queue add`, OR the agent adds them when it
detects a new `/assets/<name>/` directory that hasn't been ingested.

## Idempotence

Adding the same project-name twice is a no-op. The queue de-duplicates
by name.

## Why markdown not SQLite

Matches the rest of the nix-zeneca style. `git diff` shows queue
mutations cleanly. `auto-commit.sh` captures every change.
