# FotoStudioH (`fsh-agent`)

A fully autonomous, local-IT video editing agent.

A director drops footage into `/assets/<project>/`. The agent runs a
continuous-worker loop that takes it through ten pipeline stages
(inventory → transcribe → strategy → EDL → cut → overlay → audio →
render → self-eval → deliver) until marketing-ready deliverables land
in `/assets/<project>/output/`. Then it goes idle and waits for the
next drop.

No cloud GPU. No paid APIs. Everything runs on the host hardware.

## What the agent does

Given a folder of footage + a one-paragraph brief, the agent
autonomously:

- Reads the brief and derives platform, audience, brand, and delivery
  shape (Reels / TikTok / Shorts / LinkedIn / YouTube / broadcast)
- Inventories sources, runs orientation checks, transcribes dialogue
  (WhisperX), packs takes for editorial reading
- Researches the brand (official press CDN fetch) and the audience
  (persona matching + peer-brand recon for trending audio)
- Proposes a cut strategy with WHY lines per decision; self-approves
  in auto-mode (the user audits on return)
- Builds the EDL, extracts per-segment clips, applies grade + audio
  fades, composites overlays, burns bilingual subtitles in the
  platform's safe zone
- Produces a three-variant delivery per cut: `INTERNAL_REVIEW.mp4`
  (proposed music baked, watermarked, sign-off-only),
  `CLEAN_FOR_UI_MUSIC.mp4` (muted for platform-add-music-in-UI
  workflows), `NO_SUBS.mp4` (for re-subtitling / cross-posting)
- Packages everything into `<slug>_delivery.zip` with per-cut folders +
  `publish_instructions.txt` (caption copy, music license path,
  brand-compliance checklist, publish steps) ready for the brand team
  to airdrop to a phone
- Self-evaluates against the brief before declaring delivered; refuses
  to ship with documented gaps

Run a thin brief, get a marketing-ready package. The user is a
director, not an editor and not a programmer — the agent does the
editorial + technical work.

## Hardware requirements

| Component | Linux | macOS |
|---|---|---|
| Docker | Docker Engine 24+ + `compose` v2.20+ | Docker Desktop 4.30+ |
| GPU (optional, for speed) | NVIDIA 12 GB+ VRAM, driver ≥ 535, NVIDIA Container Toolkit | none — runs CPU-only |
| Disk | ~20 GB image + ~10 GB per active project | ~20 GB image + ~10 GB per active project |
| RAM | 16 GB+ | 16 GB+ |
| Network | needed on first build (pacman / pip / HuggingFace fetch) | same |

GPU acceleration is a speed thing, not a feature thing. With an
NVIDIA GPU, transcribe + render are GPU-accelerated and a typical
multi-cut delivery takes 15-30 min. Without GPU (any macOS, any
Linux without NVIDIA), the same delivery takes 60-90 min and is
otherwise identical — same harness, same doctrine, same self-eval
gate, same delivery zip.

## Setup

### 1. Clone with submodules

The repo has 44 third-party skill repos under `agents/` as submodules
plus hand-authored `fsh-*` skills:

```bash
git clone --recurse-submodules git@github.com:hajekad/video-edit-cc.git
cd video-edit-cc
```

(If you already cloned without `--recurse-submodules`, run
`git submodule update --init --recursive` from the repo root.)

### 2. Configure for your host

**If you have an NVIDIA GPU (Linux only):**

```bash
# Verify GPU passthrough works
docker run --rm --gpus all nvidia/cuda:12.1.0-base-ubuntu22.04 nvidia-smi
# If this doesn't print your GPU, install NVIDIA Container Toolkit:
#   sudo nvidia-ctk runtime configure --runtime=docker
#   sudo systemctl restart docker
```

Nothing else to change — `docker/docker-compose.yml` is set up for
NVIDIA out of the box.

**If you DON'T have an NVIDIA GPU (macOS, or Linux without NVIDIA):**

Comment out two blocks in `docker/docker-compose.yml`:

```yaml
#   environment:
#     - NVIDIA_VISIBLE_DEVICES=all
#     - NVIDIA_DRIVER_CAPABILITIES=compute,utility,video,graphics

#   deploy:
#     resources:
#       reservations:
#         devices:
#           - driver: nvidia
#             count: all
#             capabilities: [gpu]
```

Keep everything else (bind mounts, volumes, restart policy). The
container will run on CPU-only — slower but functional.

### 3. Build the image

```bash
cd docker
docker compose build fotostudioh-agent
```

First build takes ~15-30 min on Linux, ~30-45 min on macOS (Docker
Desktop runs an x86_64 Linux VM with Rosetta 2 on Apple Silicon).
What's happening: Arch base-devel pull, `paru` AUR builder compile,
PyTorch wheels install, WhisperX large-v3 model pre-warm (~3 GB
download into `/opt/whisper-models/`).

### 4. Bring it up

```bash
docker compose up -d fotostudioh-agent
```

The container runs `tail -f /dev/null` as a long-running entrypoint;
the agent itself is launched on demand via the alias below.

### 5. Add the convenience alias

```bash
# Linux (bash):
echo 'alias fsh-agent='"'"'docker exec -it fotostudioh-agent bash -c "cd /work && claude"'"'"'' >> ~/.bashrc
source ~/.bashrc

# macOS (zsh):
echo 'alias fsh-agent='"'"'docker exec -it fotostudioh-agent bash -c "cd /work && claude"'"'"'' >> ~/.zshrc
source ~/.zshrc
```

Identical alias on both. From here on, `fsh-agent` drops you into the
containerized Claude Code agent with the harness hot-loaded, all baked
tools on PATH, and the agent's settings preloaded.

## Using it

```bash
# 1. Drop your footage anywhere under assets/. Folder layout is yours
#    to choose — the scaffolder handles nested IDs.
mkdir -p assets/my-project
cp -r ~/footage/* assets/my-project/

# 2. (Optional) Drop a prompt.txt — anywhere from one sentence to a
#    paragraph. Brief as a director would brief, not as a programmer.
echo "Three 30-second Reels for our launch campaign. Brand voice is
energetic and irreverent. Audience is Gen-Z creators on Instagram." \
  > assets/my-project/prompt.txt

# 3. Start the agent.
fsh-agent

# 4. In the prompt, give it the brief (or "go" if you dropped a
#    prompt.txt). The agent does the rest.
```

The agent works continuously until the project reaches `delivered`.
You can `Ctrl+C` to interrupt; the loop hook auto-commits progress to
the per-project git. Outputs land in `assets/my-project/output/`.

## Repo layout

```
video-edit-cc/
├── README.md               ← you are here
├── assets/                 ← user I/O. Drop footage in /assets/<project>/.
├── work/                   ← agent's per-project workspaces (curated text-slice tracked)
├── docs/                   ← system doctrine
│   ├── PROMPT.md                   foundational brief
│   ├── BRIEF_INTERPRETATION.md     how a thin brief becomes a full delivery spec
│   ├── HARNESS_SELF_EXTENSION.md   how the agent extends its own harness
│   ├── DROPIN_SCAFFOLD_PATTERN.md  classifier-blocked asset fallback
│   ├── SOURCE_QUIRKS.md            camera / codec catalog
│   ├── ARCHITECTURE.md             pipeline stages, gates, container layout
│   ├── CAPABILITY_MATRIX.md        what's wired
│   ├── SKILL_ROUTING.md            which /agents/ submodule for which task
│   ├── ISSUE_TRACKING.md           reviewer protocol
│   └── stages/<stage>.md           per-stage operating notes
├── agents/                 ← 44 cloned skill submodules + hand-authored fsh-* skills
│   ├── CLAUDE.md                   agent operating rules
│   ├── fsh-tools/                  self-extension surface for agent-authored tools
│   ├── fsh-hooks/                  self-extension surface for agent-authored hooks
│   ├── video-use/                  the cutting engine (12 Hard Rules)
│   ├── buttercut/                  NLE-XML export
│   ├── hyperframes/                HTML/CSS → video overlays
│   ├── fsh-music-mood-bridge/      audience-to-music persona matrix
│   ├── fsh-royalty-free-music/     three-mode music workflow
│   ├── fsh-brand-assets/           official-source brand asset fetch
│   ├── fsh-editorial-theory/       Murch / Pudovkin / Pearlman cuts
│   ├── fsh-photo-composition/      photo-essay treatment
│   ├── fsh-vfx-ffmpeg/             chromakey / light-wrap / particles
│   ├── fsh-broadcast-vocal-chain/  dialogue mastering chain
│   └── ... 30+ more cloned skills
├── reference/              ← read-only context (articles, papers)
└── docker/                 ← containerized harness
    ├── Dockerfile
    ├── docker-compose.yml
    └── claude-config/
        ├── hooks/                  Stop-hook chain
        ├── commands/               slash commands (/edit, /inventory, /plan, /music, /eval, ...)
        ├── tools/                  baked CLI tools (self-eval, skill-grep, build-variants, logo-overlay, asr, ...)
        ├── delivery-presets.json   platform format specs
        ├── seed_trends.yaml        curated trending-audio catalog
        ├── settings.json           Claude Code settings
        ├── statusline.sh           statusline renderer
        ├── seed.sh                 container-start seed
        └── scaffold-project.sh     workspace scaffolder
```

## How the agent grows its own harness

The harness isn't finished — when the agent encounters a missing
capability mid-flight, it extends itself. See
[`docs/HARNESS_SELF_EXTENSION.md`](docs/HARNESS_SELF_EXTENSION.md)
for the full doctrine.

| Need | Command | Persists via |
|---|---|---|
| New system package | `agent-install <pkg>` | `agents/system-packages.txt` → next image rebuild |
| New Python package | `agent-pip-install <pkg>` | `agents/python-packages.txt` → next image rebuild |
| New tool | write to `/agents/fsh-tools/<name>` (chmod +x) | bind-mounted, on PATH via `seed.sh` |
| New hook | write to `/agents/fsh-hooks/<name>.sh`, wire in `settings.json` | bind-mounted |
| New skill | create `/agents/<name>/SKILL.md` | bind-mounted |
| New doctrine | write to `/docs/<NAME>.md` | bind-mounted |

Anything bind-mounted survives container restart AND image rebuild.
Manifest-tracked installs get re-applied on next image build.

## Three things to know about agent behavior

1. **The agent operates continuously.** It doesn't ask "should I
   proceed?" — it picks the next stage from its loop hook and works.
   To stop it, interrupt with `Ctrl+C`; otherwise it runs until
   `manifest.stage == delivered`.

2. **The agent self-evaluates before claiming delivered.** A
   structured `self-eval.verdict` written by the canonical tool gates
   the `delivered` stage. If the deliverable has documented gaps,
   missing variants, wrong dimensions, or a missing delivery zip, the
   gate fails and the agent's next directive becomes "fix the gap."

3. **The agent talks like an editor, not a programmer.** See
   `docs/PROMPT.md` § "Talk like an editor." Brief in plain English.
   Let it propose. Audit on return. The agent treats you as a
   director, not a CLI.

## License

Proprietary. See `LICENSE`. Third-party submodules under `agents/`
keep their own licenses — see each submodule's LICENSE file.

`agents/buttercut/` is PolyForm Noncommercial; treated as an isolated
non-commercial dependency. Everything else under `agents/` is
permissive (MIT / Apache / BSD).
