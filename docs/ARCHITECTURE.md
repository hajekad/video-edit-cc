# video-edit-cc — Agent Architecture

A continuous-worker video-editing agent. User drops inputs into `/assets/<project>/`, the agent runs an autonomous pipeline to produce `final.mp4` (and optional NLE XML) in `/assets/<project>/output/`. Internal state lives in `/work/<project>/`.

## Top-level layout (host)

```
~/video-edit-cc/
├── assets/                      # USER IO. Inputs + outputs. Orientation surface.
│   └── <project-name>/
│       ├── raw/                 # files dropped by user (folder/zip/single)
│       ├── prompt.txt           # optional — user's edit brief
│       └── output/              # agent writes deliverables here
│           ├── final.mp4
│           ├── final.fcpxml     # NLE XML (FCP), if requested
│           └── final.xml        # legacy NLE XML (Premiere/Resolve)
│
├── work/                        # AGENT TERRITORY. User never navigates here.
│   └── <project-id>/            # 1:1 with assets/<project-name>/ by default
│       ├── manifest.json        # MindStudio-style source of truth
│       ├── project.md           # video-use-style session memory (append-only)
│       ├── raw -> /assets/<n>/raw  # symlink, originals never mutated
│       ├── edit/                # all derived artifacts (video-use layout)
│       │   ├── takes_packed.md
│       │   ├── edl.json
│       │   ├── transcripts/<name>.json
│       │   ├── clips_graded/<idx>.mp4
│       │   ├── animations/slot_<id>/{render.mp4, ...}
│       │   ├── master.srt
│       │   ├── preview.mp4
│       │   └── final.mp4
│       ├── docs/
│       │   ├── strategy.md      # the 4-8 sentence edit plan (user-confirmed)
│       │   └── issues/<id>-<slug>.md
│       └── .claude/
│           ├── settings.json    # symlink to /opt/claude-config/settings.json
│           ├── state/
│           │   ├── issue-review/<hash>.verdict
│           │   └── self-eval.verdict
│           └── hooks/           # symlinks to /opt/claude-config/hooks/
│
├── agents/                      # 19 skill repos + system-packages.txt + CLAUDE.md
├── reference/                   # human-readable articles + PDF
├── docker/                      # container build + claude-config seed
└── docs/                        # this file + CAPABILITY_MATRIX + ISSUE_TRACKING + SKILL_ROUTING
```

## Inside the container

```
/assets   ← bind-mount from ~/video-edit-cc/assets
/work     ← bind-mount from ~/video-edit-cc/work
/agents   ← bind-mount from ~/video-edit-cc/agents
/root/.claude  ← named volume `claude-config` (auth, sessions, settings)
/root/.cache   ← named volume `hf-models` (WhisperX, HF, Torch caches)
/opt/claude-config  ← baked into image; seed.sh upserts into /root/.claude on start
/opt/ml-venv  ← baked Python venv with torch (cu121), whisperx, faster-whisper, pyannote
```

## The pipeline (stage ladder)

State lives in `manifest.json :: .stage`. Each stage has explicit on-disk
artifacts the `pipeline-gates.sh` script verifies. See `CAPABILITY_MATRIX.md`.

```
input-received      raw/ symlink present
   ↓
inventoried         ffprobe-built inputs[], takes_packed.md exists
   ↓
strategy-confirmed  docs/strategy.md exists, user OK'd it
                    (manifest.strategy.approved = true)
   ↓
edl-built           edit/edl.json valid; word-boundary-snapped
   ↓
cuts-extracted      edit/clips_graded/<idx>.mp4 for every range
                    (grade + 30ms fades applied per-segment)
   ↓
overlays-applied    edit/animations/slot_*/render.mp4 composited
                    via setpts=PTS-STARTPTS+T/TB
   ↓
audio-finalized     edit/master.srt with output-timeline offsets
   ↓
rendered            edit/preview.mp4 (subtitles applied LAST)
   ↓
self-eval-passed    .claude/state/self-eval.verdict = PASS
                    (timeline_view at every cut boundary, max 3 fix iter)
   ↓
delivered           edit/final.mp4 + optional final.fcpxml
                    copied into /assets/<n>/output/
```

## The continuous-worker loop

`Stop` hook chain runs every time the agent finishes a turn:

1. **`auto-commit.sh`** — `git add -A` + commit. Detects `status:` /
   `stage:` flips in `docs/issues/*.md` and uses them in the subject line.
2. **`loop-not-done.sh`** — finds the next action and emits a "Good. Now
   focus on this: …" sentence via stderr + `exit 2` (which keeps the
   agent working). Walks:
     a. Any `/assets/<n>/` with no `/work/<n>/`? → scaffold workspace.
     b. Otherwise pick the most-recently-modified `/work/<id>/` whose
        manifest.stage != "delivered" and dispatch the next stage action.
     c. If neither, print "drop something in /assets/" and `exit 0`.
3. **`notify-stop.sh`** — desktop `notify-send` so the user sees turn
   completion without watching the terminal.

## State-transition gating

The `PreToolUse` hook `issue-state-review.sh` denies any Edit/Write that
flips `^status:` or `^stage:` in `docs/issues/*.md` unless a fresh
(`<600s`) verdict marker exists at
`.claude/state/issue-review/<sha256(file,payload)[:16]>.verdict` with
first line `APPROVED`.

When the marker is missing, the hook returns a verbose `deny` containing
the reviewer prompt the parent agent must pass to an in-instance Agent
(`subagent_type: general-purpose`). The sub-agent reads the on-disk
artifacts and either writes the verdict marker (APPROVED) or returns a
gap list (REJECTED). The parent retries the Edit; the hook sees the
marker; allows.

Same pattern can be re-used for any "earned" state — including
`stage: delivered` on the issue tracking the whole edit.

## Skills + sub-agents

The 19 cloned repos under `/agents/` are not invoked monolithically.
The agent reads `agents/SKILL_MAP.md` (and `agents/CLAUDE.md`) at the
start of each new project and routes tasks per `SKILL_ROUTING.md`:

| Pipeline action | Primary skill | Fallback |
|---|---|---|
| Transcribe | `agents/video-use/helpers/transcribe.py` (rewritten to WhisperX) | `agents/buttercut/skills/transcribe-audio/` |
| Visual context | `agents/Claude-Video-Editor-Plugin/skills/video-timeline/` | `agents/video-use/helpers/timeline_view.py` |
| EDL building | in-instance editor sub-agent per `video-use/SKILL.md` brief | `agents/buttercut/skills/roughcut/` |
| Cut extract + grade + fades | `agents/video-use/helpers/grade.py + render.py` | `agents/Claude-Video-Editor-Plugin/skills/cut-segment/` |
| Animations: motion graphics overlay (HTML) | `agents/hyperframes/` | `agents/remotion-official-skills/` |
| Animations: math / formal | `agents/Math-To-Manim/` | `agents/manim-skill/` |
| Subtitles | `agents/Claude-Video-Editor-Plugin/skills/burn-subtitles/` (whisper.cpp / faster-whisper) | `agents/video-use/helpers/render.py --build-subtitles` |
| Audio normalize | `agents/Claude-Video-Editor-Plugin/skills/normalize-audio/` | manual ffmpeg loudnorm |
| Self-eval | `agents/video-use/helpers/timeline_view.py` at every cut boundary | — |
| Render final | `agents/video-use/helpers/render.py` | `agents/digitalsamba-toolkit/` for Remotion projects |
| NLE export | `agents/buttercut/lib/buttercut/*` (FCPXML / FCP7 / Resolve) | — |
| YouTube ingest | `agents/Youtube-clipper-skill/` | yt-dlp directly |

`agents/anthropic-skills/skills/frontend-design`, `brand-guidelines`,
`canvas-design`, `theme-factory` are referenced opportunistically when
the user asks for brand-aware visuals.

## Container hardware

- Host: RTX 3080 Ti 12GB VRAM, NVIDIA driver 580.126.09
- nvidia-container-toolkit 1.19.0 with CDI passthrough
- Compose exposes all GPUs (`NVIDIA_VISIBLE_DEVICES=all`)
- WhisperX large-v3 (~3GB), F5-TTS / XTTS v2, FLUX.2 Klein 4B,
  Qwen-Image-Edit all fit in 12GB
- Won't fit: LTX-2 22B (need cloud — out of scope for MVP per investor
  constraint of "fully AI-orchestrated local IT")

## Invariants

These hold across every project and stage. The reviewer sub-agent
enforces them at state-flip time; the agent must respect them at write
time:

1. Source files in `raw/` are **never** modified. All work happens on
   extracts in `edit/clips_graded/` and composites downstream.
2. Subtitles are applied **last** in the filter chain.
3. Per-segment extract → lossless `-c copy` concat, never single-pass
   filtergraph.
4. 30ms audio fade-in + fade-out at every segment boundary.
5. Overlay PTS shifted via `setpts=PTS-STARTPTS+T/TB`.
6. Master SRT uses output-timeline offsets, not source-time offsets.
7. Cuts snap to **word boundaries** from the WhisperX transcript.
8. Cut edges padded 30–200ms; preferred cut-target is a silence ≥400ms.
9. WhisperX **word-level verbatim** ASR only; never phrase mode.
10. Transcripts are cached per source file; never re-transcribe an
    unchanged input.
11. Multiple animations are built in **parallel** Agent sub-agents.
12. Strategy is confirmed by the user before any cut is made.
13. All session outputs go in `/work/<id>/edit/` or
    `/assets/<n>/output/` — never inside `agents/` or the system trees.

(Rules 1-12 mirror `video-use/SKILL.md` Hard Rules. Rule 13 is FSH-specific.)
