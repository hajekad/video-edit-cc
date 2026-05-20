# Stage: input-received

User has dropped artifacts into `/assets/<id>/` but the agent hasn't
yet built a workspace at `/work/<id>/`. This is the entry point.

## Entry condition

- `/assets/<id>/` exists with `raw/` files OR a single media file at root OR a zip OR a `prompt.txt`
- `/work/<id>/` does not exist (or is missing `manifest.json`)

## What to do

Run the baked scaffolder:

```bash
/opt/claude-config/scaffold-project.sh "<id>"
```

It is idempotent. Repairs missing pieces; never clobbers existing edits.

After scaffolding, the workspace contains:
- `manifest.json` initialized with `stage: input-received`
- `project.md` Session-1 header with the user prompt
- `raw/` symlink to `/assets/<id>/raw/`
- `edit/{transcripts,clips_graded,animations,verify}/` (empty)
- `docs/issues/` (empty)
- `.claude/{settings.json,hooks/}` symlinked to `/opt/claude-config/`

## Advance to: inventoried

Once the scaffold returns, `cd /work/<id>` and continue. The Stop hook
will direct you to **inventoried** next.

## Pitfalls

- **Don't mutate `/assets/<id>/raw/`.** Sources are immutable; scaffolder
  symlinks them.
- **Don't pre-populate the workspace by hand.** Use the scaffolder so
  the schema stays consistent.
- **If the user dropped a zip**, scaffolder extracts to `raw/`. The
  original zip stays in place for provenance.
