# Research: max-coverage sweep — MCPs, marketplaces, datasets, frameworks, orchestration

Background research output from a parallel agent. The "EVERYTHING we
might have missed" final sweep across five meta-dimensions.

## Top 20 high-value adds (ranked by expected utility)

| # | Item | Dim | Verdict | One-liner |
|---|---|---|---|---|
| 1 | **HKUDS/VideoAgent** | orch | clone + dissect | Closest existing implementation to FSH's design; 30-agent comparable |
| 2 | **EditDuet paper** (Adobe Research, arXiv 2509.10761) | orch | mandatory read | Editor+Critic pattern for B-roll-over-A-roll — your exact use case |
| 3 | **`Breakthrough/PySceneDetect`** | lib | clone | Shot-boundary detection — foundational, likely missing from stack |
| 4 | **MiniCPM-V 4.5** (OpenBMB) | lib | clone | Best 12GB-fit VLM for video-frame understanding; 96× token compression |
| 5 | **`LAION-AI/aesthetic-predictor`** | dataset | clone | Score any frame in 5ms; thumbnail/social-cut selection becomes automatic |
| 6 | **`qdrant/mcp-server-qdrant`** | mcp | clone | The only MCP that fills semantic-asset-search gap; local |
| 7 | **`anthropics/claude-agent-sdk-demos`** | orch | clone | First-party multi-agent-research demo to copy patterns from |
| 8 | **BBC Sound Effects Archive** + bulk downloader (FThompson) | dataset | download once | ~16k pro SFX with tags; gold-standard free corpus |
| 9 | **`TMElyralab/MuseTalk` 1.5** | lib | clone | Selective dub/relip on 12GB; sharper than Wav2Lip |
| 10 | **`facebookresearch/demucs`** (htdemucs_ft) | lib | clone | Stem separation for music-editorial agent |
| 11 | **`colour-science/colour`** (Python) | lib | clone | Local 3D LUT + ACES/log-space color pipeline without Resolve |
| 12 | **`snakers4/silero-vad`** | lib | clone | Production VAD for silence-trim + speech-section pickout |
| 13 | **`dmlc/decord`** | lib | clone | 2-4× faster frame iteration than ffmpeg-piped for per-frame analysis |
| 14 | **`MTG/freesound-python`** + Freesound API | dataset | configure | Pull-on-demand CC-licensed SFX by tag |
| 15 | **GLANCE paper + planned code** (HKUDS, AAMAS 2026) | orch | study + watch repo | Music-grounded multi-agent editing |
| 16 | **`anthropics/skills` + `anthropics/claude-cookbooks`** | mkt | already cloned | First-party SKILL.md templates |
| 17 | **`VoltAgent/awesome-agent-skills`** (22K★) | mkt | bookmark + cherry-pick | Highest-signal community aggregator |
| 18 | **`DareDev256/fcpxml-mcp-server`** | mcp | bookmark | Deterministic FCPXML manipulation as MCP |
| 19 | **Pexels API + Pixabay API** | dataset | configure | Free programmatic B-roll on demand |
| 20 | **`samuelgursky/davinci-resolve-mcp`** | mcp | reference now / clone if Studio license | Direct AI→NLE bridge if user moves to Resolve Studio |

## Dimension 1 — MCP server sweep

| Repo | Verdict | Notes |
|---|---|---|
| `qdrant/mcp-server-qdrant` | **clone** | Apache-2.0. Semantic asset search via local Qdrant. Fills the gap nothing else does. |
| `samuelgursky/davinci-resolve-mcp` | reference (needs Resolve Studio license) | 215-328 tools exposing full Resolve scripting API |
| `DareDev256/fcpxml-mcp-server` | bookmark | FCPXML parse/emit/timeline-analyze without NLE installed |
| `leancoderkavy/premiere-pro-mcp` | skip | Needs Premiere license |
| `conneroisu/vfx-mcp` | skip | Overlaps misbahsy/video-audio-mcp already evaluated |
| Plex MCP | skip | Only useful if footage already in Plex |
| transloadit / cloudinary / filespin / AEM DAM MCPs | skip | All paid SaaS |

**Honest finding**: no strong OSS DAM MCP exists. Build a small Qdrant-backed asset-manager MCP rather than adopt one.

## Dimension 2 — Skill marketplaces / aggregators

| Source | Verdict |
|---|---|
| `VoltAgent/awesome-agent-skills` (22K★) | **bookmark + cherry-pick** — highest signal-to-noise |
| `hesreallyhim/awesome-claude-code` (44K★) | bookmark — canonical "awesome" list, CSV-indexed |
| `jeremylongshore/claude-code-plugins-plus-skills` (2.2K★) | bookmark, browse selectively — 425 plugins / 2810 skills, ccpi CLI |
| `anthropics/skills` | clone (already done) |
| `anthropics/claude-cookbooks` | clone (already done) |
| SkillsMP / claudeskills.info / skills.pawgrammer / skillhub.club / claudemarketplaces.com | skip — smaller mirrors / meta-directories |
| `rohitg00/awesome-claude-code-toolkit` | skip — but **bookmark `rohitg00/skillkit`**: portable-skill translator across Claude/Cursor/Codex/Copilot |

## Dimension 3 — Datasets + reference corpora

**Audio / SFX:**
- **BBC Sound Effects Archive** (archive.org/details/bbcsoundeffects + `FThompson/BBCSoundDownloader`) — ~16K pro SFX with tags. Internet-Archive mirror. **Gold-standard free corpus.**
- **Freesound + `MTG/freesound-python`** — per-clip CC0/CC-BY/CC-BY-NC filterable. OAuth2 for full-quality. Pull-on-demand pattern.
- **Pixabay + Pexels free-music APIs** — free commercial, no attribution (Pixabay) / Pexels license. Configure API keys.
- **dig.ccMixter** + `dohliam/ccmixter-download` — deepest CC-licensed music corpus with mood/instrument/genre tag search.

**Video / footage:**
- **Prelinger Archives** + Internet Archive `stock_footage` — 8,500+ public-domain films. Critical for documentary domain.
- **Wikimedia Commons video** — smaller corpus, cleaner license metadata.

**Image / aesthetic-scoring:**
- **`LAION-AI/aesthetic-predictor`** + `christophschuhmann/improved-aesthetic-predictor` — linear model on CLIP ViT/14, scores images 1-10 for aesthetic quality. Inference is essentially free. **Single most actionable item: score every frame/thumbnail of generated content with one extra model call.**
- **AVA dataset** (academictorrents) — 250K images with aesthetic scores. Research-only license.

**Video understanding benchmarks:**
- EgoSchema, VideoMME, NExT-QA — reference-only, for calibrating any video VLM choice.

## Dimension 4 — Frameworks + libraries

### Video I/O alternatives
- **`dmlc/decord`** — GPU-accelerated decoder, 2× faster than OpenCV/PyAV. **Clone.**
- **`PyAV-Org/PyAV`** — Pythonic ffmpeg binding. Bookmark; skip unless Decord limits hit.

### Scene detection
- **`Breakthrough/PySceneDetect`** — best-in-class shot/cut detector. detect-content, detect-adaptive, detect-threshold, detect-hash. **Clone — every video-editing agent needs shot boundaries.**

### Silence / voice
- **`WyattBlue/auto-editor`** — automates silence-removal. Bookmark.
- **`snakers4/silero-vad`** — production VAD model. MIT. CPU offline. **Clone.**

### Forced alignment
- **`readbeyond/aeneas`** — audio↔text forced alignment, 38 languages. **AGPL-3, reference-only.** WhisperX handles most cases.

### Lip-sync / avatar
- **`TMElyralab/MuseTalk` 1.5** — real-time latent-diffusion lip-sync. 30fps+ on V100, fits 12GB RTX cards. Sharper than Wav2Lip. **Clone (replaces SadTalker for selective dub overlay).**
- **`saifhassan/Wav2Lip-HD`** — bookmark as MuseTalk fallback.

### Vision-LM for video frames
- **`OpenBMB/MiniCPM-V` 4.5** — ~8B params omnimodal, 5.5GB on disk, 12GB GPU min. Compresses 6× 448×448 video frames into 64 tokens. **Top pick for 3080 Ti.**
- Qwen2.5-VL-7B — bookmark; slightly larger memory footprint.
- LLaVA-NeXT Video — reference-only; older than MiniCPM-V 4.5.

### Stem separation
- **`facebookresearch/demucs`** htdemucs_ft — SOTA, MIT, fits 3080 Ti. **Clone.**

### Color science
- **`colour-science/colour`** — Python lib. Full LUT (1D/3×1D/3D) read/write/invert. ACES, ARRI Log, DaVinci WG, BMD WG. **Clone for programmatic color pipelines without Resolve.**
- **`ethan-ou/camera-match`** — RBF-based custom 3D LUTs. Bookmark for multicam matching.

### Multimodal RAG
- **`HKUDS/VideoRAG`** (KDD 2026) — dual-channel "Vimo" architecture, handles hundreds of hours. Reference-only — heavy.
- **`13331112522/m-rag`** — ~300-line multimodal RAG, Ollama + LLaVA. Reference-only.

### Narrative / story arc — honest gap
No good standalone Python library exists. Vonnegut/UVM "shapes-of-stories" approach uses ad-hoc sentiment-over-time. Roll your own with transcript + VADER/spaCy.

## Dimension 5 — Workflow / orchestration patterns

### Anthropic-official (highest value)
- **`anthropics/claude-agent-sdk-demos`** — clone. Multi-agent-research demo is the canonical reference pattern.
- **`anthropics/claude-cookbooks`** — clone. `/skills` subfolder is the canonical SKILL.md template.
- **Claude Code docs: Agent Teams** — bookmark; enable when stable.

### Curated repos
- **`wshobson/agents`** — 185 specialized agents, 16 multi-agent workflows. Bookmark, study orchestrator-pattern files.
- **`ruvnet/ruflo`** — swarm-style orchestration with RAG. Reference-only.

### Research papers (May 2026)
- **EditDuet** (Adobe Research, SIGGRAPH 2025, arXiv 2509.10761) — Editor + Critic multi-agent for B-roll-over-A-roll. 8.2% failure rate, 89.8% time-coverage. **Read this before final architecture lock — your exact use case.**
- **GLANCE** (AAMAS 2026, arXiv 2604.05076) — global-local coordination multi-agent for music-grounded NLE. Watch `ZihaoLinQZ/GLANCE-Video-Editing-Agent`.
- **Prompt-Driven Agentic Video Editing System** (arXiv 2509.16811) — long-form temporal segmentation + memory compression. Reference-only.
- **`HKUDS/VideoAgent`** — All-in-one 30-agent framework w/ intent parsing + self-reflective graph orchestration. **Closest published implementation to FSH; clone + dissect.**
- **FilmAgent** (arXiv 2501.12909) — director/screenwriter/actor/cinematographer roles. 3D not real footage but role-decomposition pattern transfers.
- **Cutscene Agent** (arXiv 2604.25318) — bidirectional MCP between LLM and game engine. Reference-only.

### Awesome lists for agent-building
- `yunlong10/Awesome-LLMs-for-Video-Understanding` — IEEE TCSVT tracker; bookmark.
- `VoltAgent/awesome-ai-agent-papers` — 2026-focused; bookmark.
- `punkpeye/awesome-mcp-clients` + `awesome-mcp-devtools` — bookmark devtools.
- `kaushikb11/awesome-llm-agents` — bookmark.

## Honest gaps where nothing new surfaced

1. **Render farm MCP** — nothing local; Render.com is paid. Build ffmpeg-distribution wrapper.
2. **DAM MCP (open-source)** — all meaningful ones are paid. Build with Qdrant.
3. **Story-arc Python library** — roll your own with transcript + VADER/spaCy.
4. **Reviewer-agent / harsh-critique patterns** — covered by agent #6 (report 04).
