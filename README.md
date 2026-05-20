# FotoStudioH (`fsh-agent`)

A fully autonomous, fully local-IT video editing agent.

A director drops footage into `/assets/<project>/`. The agent runs a
continuous-worker loop that takes it through ten pipeline stages
(inventory → transcribe → strategy → EDL → cut → overlay → audio →
render → self-eval → deliver) until a marketing-ready deliverable
lands in `/assets/<project>/output/`. Then it goes idle.

No cloud GPU. No paid APIs. Everything runs on the host hardware.

---

## What it actually produces

Smoke-tested against the ORLEN / Unipetrol Pyrolyza Květen footage
(Q2-2026, 7-cut Instagram Reels delivery):

- 7 different cuts targeting different audience subsets (ESG investors,
  EU partners, engineering recruits, regional community, brand hero,
  process-mechanism explainer, meme-register pivot)
- 2-3 variants per cut: `<cut>_INTERNAL_REVIEW.mp4` (music baked,
  watermarked, sign-off only) + `<cut>_CLEAN_FOR_UI_MUSIC.mp4` (muted,
  for Instagram-add-music-in-UI workflow) + `<cut>_NO_SUBS.mp4` (for
  re-subtitling / repurposing)
- Per-cut `publish_instructions.txt` with CZ+EN captions, music license
  path, brand-compliance checklist, publish steps
- Bilingual Czech + English burn-in subtitles, safe-zone-aware
- Real ORLEN brand lockup on every cut (fetched autonomously from
  orlen.pl press CDN)
- `<slug>_delivery.zip` ready for the brand team to airdrop to a phone

Full deliverable lands as ~900 MB zip + loose files. From a one-line
brief, agent-only, no manual editorial intervention.

---

## Hardware requirements

| Component | Required | Why |
|---|---|---|
| OS | **Linux** (tested: Fedora-based) | NVIDIA Container Toolkit + CDI passthrough is Linux-only |
| GPU | **NVIDIA, 12 GB+ VRAM** (tested: RTX 3080 Ti) | WhisperX large-v3 + ffmpeg NVENC + future image-gen / TTS |
| Driver | NVIDIA driver ≥ 535 | CUDA 12.1 wheels |
| Docker | Docker Engine 24+ with `compose` plugin v2.20+ | container build + GPU passthrough via CDI |
| NVIDIA Container Toolkit | installed + `nvidia-ctk runtime configure` done | GPU inside container |
| Disk | ~20 GB for image + ~10 GB+ per active project | Image bakes WhisperX large-v3 weights (~3 GB), CUDA wheels (~6 GB) |
| Network | Public internet on first build | Pacman + pip + HuggingFace model fetch |

**macOS support:** the agent does NOT run natively on macOS — no CUDA,
no NVENC, no Linux-only ML wheels. See [Working from macOS](#working-from-macos)
below for the practical path (SSH / VS Code remote into a Linux host).

---

## Setup (one-time, on the Linux GPU host)

```bash
# 1. Clone with submodules (44 third-party skill repos under agents/)
git clone --recurse-submodules git@github.com:hajekad/FotoStudioH.git
cd FotoStudioH

# (or if you already cloned without --recurse-submodules:)
git submodule update --init --recursive
```

```bash
# 2. Verify GPU passthrough works in Docker
docker run --rm --gpus all nvidia/cuda:12.1.0-base-ubuntu22.04 nvidia-smi
# should print your GPU. If not: install NVIDIA Container Toolkit
# + run `sudo nvidia-ctk runtime configure --runtime=docker`
# + restart docker daemon.
```

```bash
# 3. Build the image (takes ~15-30 min the first time — pulls Arch
#    pacman repos, builds paru from AUR, installs the ml-venv with
#    PyTorch CUDA 12.1 wheels, downloads WhisperX large-v3 to bake
#    into /opt/whisper-models/)
cd docker
docker compose build fotostudioh-agent
```

```bash
# 4. Bring the container up (it will tail -f /dev/null as a long-running
#    process; the agent runs inside it via the alias below)
docker compose up -d fotostudioh-agent
```

```bash
# 5. Add the convenience alias to your shell
echo 'alias fsh-agent='"'"'docker exec -it fotostudioh-agent bash -c "cd /work && claude"'"'"'' >> ~/.bashrc
source ~/.bashrc
```

That's it. The agent is now containerized at
`fotostudioh-agent`, hot-loaded with the harness, GPU available,
WhisperX pre-warmed, all 12 baked tools on PATH.

---

## Using it

```bash
# 1. Drop your footage anywhere under /assets/
mkdir -p assets/Q2-2026/MyProject
cp -r ~/footage/* assets/Q2-2026/MyProject/
# Optional: drop a prompt.txt — anywhere from 1 sentence to a paragraph
echo "Make me three 30s Reels from this footage. Brand: Acme. Audience: Gen-Z creators." \
  > assets/Q2-2026/MyProject/prompt.txt

# 2. Start the agent
fsh-agent

# 3. In the Claude Code prompt, give it the brief (or just "go" if you
#    dropped a prompt.txt). The agent does the rest.
```

The agent will:
- Scaffold a workspace at `/work/<slug>/`
- Run the three-pass brief read (surface / signal / audience) per
  [`docs/BRIEF_INTERPRETATION.md`](docs/BRIEF_INTERPRETATION.md)
- ffprobe + orientation-check every source
- Transcribe via WhisperX (Czech, English, or auto-detect)
- Match an audience persona from
  `agents/fsh-music-mood-bridge/personas.yaml`
- WebFetch the brand's official press page for the logo
- Trend-scout peer-brand audio + pitch-fetch via yt-dlp (for proposal
  artifacts only, under the fair-use-for-pitch envelope)
- Render each cut at the platform's spec (Reels 1080×1920 @ 30fps,
  H.264 NVENC, safe-zone-aware subtitle anchor)
- Build the variants via `build-variants` + the `_INTERNAL_REVIEW` /
  `_CLEAN_FOR_UI_MUSIC` / `_NO_SUBS` convention
- Run brief-aware self-eval — refuses to declare delivered with
  documented gaps or stale audio
- Stage to `/assets/<id>/output/` + produce the `<slug>_delivery.zip`
  with per-cut folders + `publish_instructions.txt`

Total runtime per project: 10-30 min depending on source length + cut
count + GPU.

---

## Working from macOS

The agent doesn't run natively on macOS — no CUDA, no NVENC, no Linux-only
ML wheels. Three practical paths:

### Recommended: VS Code Remote over SSH to a Linux GPU host

You operate from your Mac; the agent runs on a Linux+NVIDIA box you have
SSH access to (workstation, dedicated build box, friend's machine).

```bash
# On the Linux host: see Setup above. Once running:
docker compose up -d fotostudioh-agent
```

```bash
# On the Mac:
# 1. Install VS Code + the "Remote - SSH" extension
# 2. Cmd+Shift+P → "Remote-SSH: Connect to Host" → ssh user@linux-host
# 3. Open the FotoStudioH repo from the remote filesystem
# 4. In the integrated terminal: fsh-agent
```

All editing, all tooling, all renders run on the Linux side. Your Mac
is the keyboard + monitor. Drag-and-drop into `assets/` works through
VS Code's remote file explorer. Outputs in `assets/<id>/output/` show
up in the same browser.

### Alternative: SSH + tmux (no VS Code)

```bash
# On the Mac terminal:
ssh -t user@linux-host "cd ~/FotoStudioH && tmux new -A -s fsh && fsh-agent"
```

Same agent experience, terminal-only. Detach with `Ctrl-b d`, reattach
with the same command. Useful for long-running renders you don't want
tied to your Mac being awake.

### Code-review-only: clone locally, don't try to run

```bash
# On the Mac:
git clone --recurse-submodules git@github.com:hajekad/FotoStudioH.git
cd FotoStudioH
```

Everything is browsable — read `docs/`, `agents/`, the slash commands
under `docker/claude-config/commands/`, the hooks, the tools. You can
inspect every smoke-test output trail in `work/<slug>/`. You just
can't `docker compose up` and have it work (the image's CUDA wheels
fail on macOS).

If you really want to try a Mac-local build with CPU-only fallback,
the path exists but performance is brutal (faster-whisper on CPU is
~10x slower than GPU, NVENC renders fall back to libx264 software
encoding). Not recommended for actual work.

---

## How it's organized

```
FotoStudioH/
├── README.md               ← you are here
├── assets/                 ← USER I/O. Drop footage in /assets/<project>/.
├── work/                   ← agent's per-project workspace + curated text-slice
│                              tracking (its own git repo, no upstream)
├── docs/                   ← system doctrine
│   ├── PROMPT.md                   foundational brief — read this first
│   ├── BRIEF_INTERPRETATION.md     how the agent turns a thin brief into a full delivery spec
│   ├── HARNESS_SELF_EXTENSION.md   how the agent grows its own harness
│   ├── DROPIN_SCAFFOLD_PATTERN.md  how blocked-fetch assets get drop-in scaffolded
│   ├── SOURCE_QUIRKS.md            living catalog of camera/codec quirks (Sony VVHA vertical-stored-landscape, etc.)
│   ├── ARCHITECTURE.md             pipeline stages, gates, container layout
│   ├── CAPABILITY_MATRIX.md        descriptive tracker of what's wired
│   ├── SKILL_ROUTING.md            which /agents/ submodule for which task
│   ├── ISSUE_TRACKING.md           reviewer-sub-agent protocol
│   └── stages/<stage>.md           per-pipeline-stage operating notes
├── agents/                 ← 44 cloned skill submodules + 6 hand-authored fsh-* skills
│   ├── CLAUDE.md                   the agent's operating rules
│   ├── fsh-tools/                  agent-authored tools (self-extension surface, bind-mounted)
│   ├── fsh-hooks/                  agent-authored hooks (self-extension surface, bind-mounted)
│   ├── fsh-brand-assets/           brand asset fetch doctrine
│   ├── fsh-music-mood-bridge/      audience-to-music-mood matrix (21 personas)
│   ├── fsh-royalty-free-music/     three-mode music workflow
│   ├── fsh-editorial-theory/       Murch / Pudovkin / Pearlman cuts
│   ├── fsh-photo-composition/      photo-essay treatment doctrine
│   ├── fsh-vfx-ffmpeg/             chromakey / light-wrap / particles
│   ├── fsh-broadcast-vocal-chain/  6-stage dialogue mastering chain
│   ├── video-use/                  the cutting engine (12 Hard Rules)
│   ├── buttercut/                  NLE-XML export (FCP X / Premiere / Resolve)
│   ├── hyperframes/                HTML/CSS → video overlays
│   └── ... 30+ more
├── reference/              ← read-only context (saved articles, arXiv papers)
└── docker/                 ← containerized harness
    ├── Dockerfile          baseline image (arch base-devel + ffmpeg + uv + ml-venv + paru)
    ├── docker-compose.yml  bind mounts, GPU passthrough, named volumes
    └── claude-config/      hooks, slash commands, baked tools, settings
        ├── hooks/                  Stop-hook chain (auto-commit, memory-check, loop-not-done, etc.)
        ├── commands/               slash commands (/edit, /inventory, /plan, /music, /eval, ...)
        ├── tools/                  baked CLI tools (self-eval, skill-grep, build-variants, logo-overlay, asr, ...)
        ├── delivery-presets.json   platform format specs (Reels / TikTok / Shorts / LinkedIn / YouTube / broadcast)
        ├── seed_trends.yaml        curated trending-audio catalog (peer-brand observations)
        ├── settings.json           Claude Code settings
        ├── statusline.sh           statusline renderer
        ├── seed.sh                 container-start seed (symlinks /opt → /root, PATH wiring, git safe-directory)
        └── scaffold-project.sh     workspace scaffolder
```

---

## How the agent grows its own harness

The harness isn't finished — when the agent encounters a missing
capability mid-flight, it extends itself. See
[`docs/HARNESS_SELF_EXTENSION.md`](docs/HARNESS_SELF_EXTENSION.md)
for the full doctrine. Short version:

| Need | Command | Persists via |
|---|---|---|
| New system package | `agent-install <pkg>` | `agents/system-packages.txt` → Dockerfile reads on next rebuild |
| New Python package | `agent-pip-install <pkg>` | `agents/python-packages.txt` → Dockerfile pip-installs on next rebuild |
| New tool | write to `/agents/fsh-tools/<name>` (chmod +x) | bind-mounted; on PATH via `seed.sh` |
| New hook | write to `/agents/fsh-hooks/<name>.sh`, add to settings.json | bind-mounted |
| New skill | create `/agents/<name>/SKILL.md` | bind-mounted |
| New doctrine | write to `/docs/<NAME>.md` | bind-mounted |

Anything bind-mounted survives container restart AND image rebuild.
Anything in a manifest (`system-packages.txt`, `python-packages.txt`)
gets re-installed on next image build.

---

## Three things the colleague should know

1. **The agent operates continuously.** It doesn't ask "should I proceed?"
   It picks the next stage from its loop hook and works. If you want
   to stop it, interrupt with `Ctrl+C`; otherwise it runs until
   `manifest.stage == delivered`.

2. **The agent self-evaluates before claiming delivered.** A
   structured `self-eval.verdict` written by the canonical tool gates
   the `delivered` stage. If the deliverable has documented gaps,
   missing variants, wrong dimensions, or a missing delivery zip, the
   gate fails and the agent's next directive becomes "fix the gap."

3. **The agent talks to the user like an editor, not a programmer.**
   Read `docs/PROMPT.md` § "Talk like an editor" — when chatting with
   it, treat it like a director/editor in a creative review, not like
   a CLI. Brief in plain English. Let it propose. Audit on return.

---

## Smoke-test history

- **Smoke #1 (May 2026):** single 75s vertical hero, agent self-discovered transpose=2 on Sony footage, hit WhisperX install gap (manual recovery), no music + no logo. ~25% confidence pre-run; delivered.
- **Smoke #2 (May 2026):** added hero + landscape + teaser, sine-tone audio failure mode (banned post-mortem), manual logo workaround. Drove the dropin-scaffold doctrine + pitch-music-fetch + watermark + auto-advance + memory doctrine.
- **Smoke #3 (May 2026):** 7-cut Reels deliverable, all music-split honored (4 trend-scouted + 3 AudioJungle previews), real ORLEN logo fetched autonomously from press CDN, brand-pollution self-audit, agent self-corrected orientation bug via mandatory QC verify. Multi-cut planning landed correctly. Drove the self-extension scaffolding ("last click") + four-stance CLAUDE.md preamble + skill-grep + brief-aware self-eval gate.

Each smoke test's discoveries became permanent harness features. The
current state is what's in `main`.

---

## License

Proprietary. See `LICENSE`. Third-party submodules under `agents/`
keep their own licenses — see each submodule's LICENSE file.

`agents/buttercut/` is PolyForm Noncommercial; treated as an isolated
non-commercial dependency. Everything else under `agents/` is
permissive (MIT / Apache / BSD).
