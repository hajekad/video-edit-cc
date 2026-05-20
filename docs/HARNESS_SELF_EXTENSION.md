# Harness Self-Extension Doctrine

The harness you operate in (`fsh-agent`) is not a finished product. It
is a working frame that grows as you encounter what it lacks. When you
need a tool, a Python dep, a system package, a hook, a skill, or a
doctrine that doesn't yet exist, you ADD it. The pilot that watched
you through the first three smoke tests has stepped away — the harness
grows from inside now.

The single rule that makes this work:

> **Whatever you add must survive the next image rebuild.** If it
> doesn't, your future self will encounter the same gap and rediscover
> it from scratch. Mark every addition in the right place so the next
> `docker compose up --build` carries it forward automatically.

## Persistence tiers (know which one you're writing into)

| Tier | Paths | Survives container restart? | Survives image rebuild? | Use for |
|---|---|---|---|---|
| **1. Bind-mounted from host repo** | `/agents/`, `/docs/`, `/work/`, `/assets/`, `/reference/` | yes | yes (it's in git) | new tools, hooks, skills, doctrines — DEFAULT for anything you author |
| **2. Image-baked** | `/opt/claude-config/`, `/opt/ml-venv/`, `/usr/local/bin/` | yes | NO unless manifested | system packages, pip packages, the canonical baked tooling |
| **3. Named volumes** | `/root/.claude/`, `/root/.cache/`, `/var/cache/pacman/` | yes | NO (volume persists but not under your control) | auth, sessions, model weights cache, pacman cache |
| **4. Container writable layer** | everything else (`/tmp`, `/var/log`, `/opt/whisper-models/`, etc.) | yes | NO | scratch only — anything important must be in tier 1 or manifested for tier 2 |

**Rule of thumb:** prefer tier 1 always. If you write to tier 2/3/4,
you owe a manifest entry so the next image build re-creates it.

## The four self-extension surfaces

### 1. System packages (pacman + AUR)

```bash
agent-install <pkg> [<pkg>...]
```

Does two things at once:
- Installs immediately via `paru` (works for both official repos and AUR)
- Appends to `/agents/system-packages.txt`

The Dockerfile reads `agents/system-packages.txt` at build time and
re-installs everything listed. Your install survives the next rebuild
because the manifest is in the git repo.

### 2. Python ML / scripting packages

```bash
agent-pip-install <pkg> [<pkg>...]
```

Does two things at once:
- Pip-installs into `/opt/ml-venv/` immediately
- Appends to `/agents/python-packages.txt`

Same pattern as system packages — the Dockerfile reads the manifest at
build time. Use this for anything Python: HuggingFace libs, video
processing, audio tools, ML models, scrapers, anything.

### 3. New tools you author

Write the executable directly into `/agents/fsh-tools/<name>`:

```bash
cat > /agents/fsh-tools/peer-brand-reels-recon <<'EOF'
#!/usr/bin/env python3
# ... your tool ...
EOF
chmod +x /agents/fsh-tools/peer-brand-reels-recon
```

This directory is bind-mounted from the host repo. `seed.sh` puts it
on `PATH` at container start. Your tool is:
- Available immediately under its bare name
- Survives container restart (bind mount)
- Survives image rebuild (it's in the git repo)
- Visible to future agents reading the routing tables

**Don't write tools to `/opt/claude-config/tools/`** — that's the
canonical baked tooling, mutated only via the Dockerfile COPY at build
time. Your authored tools live in `/agents/fsh-tools/` instead.

When you write a new tool, also append a row to
`/docs/SKILL_ROUTING.md` describing what it does and when to call it.
Without that entry, the next agent won't discover it.

### 4. New hooks (Stop / PreToolUse / etc.)

Write the hook to `/agents/fsh-hooks/<name>.sh`:

```bash
cat > /agents/fsh-hooks/my-new-stop-hook.sh <<'EOF'
#!/usr/bin/env bash
# ... ...
EOF
chmod +x /agents/fsh-hooks/my-new-stop-hook.sh
```

To activate it, edit `/root/.claude/settings.json` and add it to the
appropriate hooks chain. (`settings.json` is in a named volume — your
edit persists across restarts. For image rebuilds, settings.json is
re-seeded from `/opt/claude-config/settings.json` so update that on
the host too if you want the chain change baked in.)

### 5. New skills

Create `/agents/<skill-name>/SKILL.md` with the standard frontmatter:

```markdown
---
name: <skill-name>
description: <one-line summary used during routing>
version: 0.1.0
---

# <skill-name>

<body>
```

Bind-mounted from host, no further wiring needed. Register the skill
in `/docs/SKILL_ROUTING.md` so the next agent finds it.

### 6. New doctrines

Write to `/docs/<DOCTRINE_NAME>.md`. Bind-mounted, in repo. Reference
it from `/docs/PROMPT.md`'s reading order if it's load-bearing.

### 7. New personas

Append to `/agents/fsh-music-mood-bridge/personas.yaml`. Bind-mounted,
in repo. Use existing personas as templates.

### 8. New camera / codec quirks

Append to `/docs/SOURCE_QUIRKS.md`. Living catalog — the agent that
hits a new quirk documents it so the next agent doesn't re-discover.

### 9. New delivery presets

Edit `/opt/claude-config/delivery-presets.json` if the running
container needs to see it immediately. ALSO copy your edit to
`/home/adam/video-edit-cc/docker/claude-config/delivery-presets.json` on
the host via the docker socket so it survives rebuild — OR just edit
the host file via `docker exec` writing back through any host-visible
bind mount you can reach.

(In practice: delivery presets get added rarely enough that the
"author on host, propagate to /opt via the symlink" pattern is fine.)

### 10. New trending audio observations

Append to `/opt/claude-config/seed_trends.yaml` (the curated catalog).
Same caveat as delivery presets — the file lives in `/opt`, so for
permanence either propagate to host or write the entry into
`/agents/fsh-trends/<date>.yaml` as a sidecar that the next image
build merges in. For now, write to seed_trends.yaml; the post-mortem
will collect entries into the canonical file.

## Anti-patterns

- **Installing without manifesting.** `paru -S foo` without
  `agent-install foo` means foo disappears on next rebuild. Use the
  wrappers.
- **Writing tools to `/opt/claude-config/tools/`.** That's the baked
  canonical tooling. Your authored tools belong in `/agents/fsh-tools/`.
- **Writing to `/root/.claude/`** with the intent of permanence. It's a
  named volume — survives container restart but not image rebuild and
  is unfriendly to inspect from the host. Use `/agents/` paths instead.
- **Forgetting the routing table.** A tool no one knows about may as
  well not exist. Always update `/docs/SKILL_ROUTING.md`.
- **Skipping the doctrine note.** When you discover something
  non-trivial (a workflow that works, a failure mode that always
  re-emerges, a new constraint), write it into a doctrine file. The
  next agent saves the time you spent.

## When to refuse to self-extend

- If the user explicitly said "don't install X" or "don't write
  outside this directory", honor that even when the harness would
  permit the write.
- If you can solve the immediate task with existing tooling, prefer
  that — self-extension is for missing capabilities, not for
  preference variations.
- If the addition would require a new external network egress to a
  source that the classifier blocks, don't try to engineer around the
  classifier — file a `Capability` issue and use the drop-in scaffold
  instead.

## Promise, then wire

The capability matrix is descriptive (what's wired right now); it is
NOT prescriptive (what you can promise). When a brief calls for a
capability that's at `engine-not-wired` or `missing`:

1. **Promise it in the strategy / response.** The user's deliverable
   doesn't care which internal stage a capability sits at. Trust is
   formed by promises kept, broken by promises quietly downgraded.
2. **Make the wiring your next subtask, same session.** With the
   self-extension surfaces above (system pkgs, pip pkgs, fsh-tools,
   fsh-hooks, skills, doctrines), nothing in the matrix is more than
   a few hours of work from `production-ready`. If the engine isn't
   wired, wire it. If the library doesn't exist, install it. If the
   skill repo isn't cloned, clone it under `/agents/<name>/`.
3. **Update the matrix as you go.** When you wire something, edit
   `/docs/CAPABILITY_MATRIX.md` in the same change. Move the row to
   `wired-unvalidated`. The matrix is your tracking surface, not your
   excuse surface.

The only honest refusals are:
- Hardware-physical (LTX-2 22B doesn't fit in 12 GB VRAM)
- Paid-only without user authorization (no $-spending unless they said)
- Hard classifier blocks that survive even single-URL fetch attempts
- User explicitly forbade it
- Distribution-licensing for public deliverables when no license
  proof exists

Anything else, you wire. Document in the issue file with the specific
constraint, not "out of scope."

## When something errors

The first three smoke tests had an external pilot fixing things
mid-flight. That pilot is gone. When your tool errors, your render
fails, your fetch returns 403:

1. Read the error. The cause is usually right there.
2. Try the obvious fix: missing dep → `agent-pip-install`. Wrong path
   → correct it. Classifier denial → switch to the single-URL or
   drop-in path documented in DROPIN_SCAFFOLD_PATTERN.md. Version
   drift → pin the version and add to the relevant manifest.
3. If the obvious fix fails: read the deeper cause. Look at the
   library source under `/opt/ml-venv/`, the script under
   `/opt/claude-config/tools/`, the failing ffmpeg filter graph.
   Author a wrapper that routes around the broken path
   (`/opt/claude-config/tools/asr` was authored exactly this way
   after WhisperX/pyannote drift broke the CLI).
4. Only escalate to the user when the root cause is genuinely outside
   your reach. Even then, propose the concrete unstick path; don't
   stop at "blocked." The watermark-when-music-fetch-blocked pattern
   from smoke #2 is the template: ship something honest with the gap
   clearly marked, not nothing because the path was hard.

The trust formula: promise → wire → deliver. The doctrine above
makes "wire" the agent's responsibility, in-flight, without external
intervention.

## The Why

The first three smoke tests had an external pilot patching the
harness as gaps emerged. The "last click" — this doctrine — gives you
the same patching power, plus persistence into future builds. Use it
when the harness lacks what the work needs. Document as you go.
