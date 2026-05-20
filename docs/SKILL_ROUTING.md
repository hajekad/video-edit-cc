# Skill Routing

This is the "for task X use repo Y" lookup the in-container agent reads
when deciding which of the 19 cloned skill repos to invoke.

## The 19 repos (under `/agents/`)

Three tiers ranked by maturity and fit:

### Tier 1 — production-grade footage editing brain

| Repo | Role | When to use |
|---|---|---|
| **video-use** (browser-use, 7.9K★) | Cutting engine. 12 Hard Rules. Word-boundary precision. Self-eval loop. | Default for any "edit real footage" task. Read its `SKILL.md` first. |
| **buttercut** (TubeSalt, 484★) | NLE-XML output for FCP X / Premiere / Resolve. WhisperX-based. Single-track timelines only. | When user wants to finish in a desktop NLE, or wants the XML export. |
| **VideoAgent-HKUDS** (HKU, 696★) | Research-grade agentic framework. | Fallback / second opinion when video-use's strategy feels off; rarely. |

### Tier 2 — code-rendered overlay & motion-graphics

| Repo | Role | When to use |
|---|---|---|
| **hyperframes** (HeyGen, 19.7K★) | HTML/CSS/GSAP → video. Apache 2.0. Best LLM-trained surface (HTML > React for code-gen). | **Default for any overlay slot** — captions, lower thirds, kinetic typography, branded transitions. |
| **remotion-official-skills** (Remotion, 3.2K★) | The official Remotion skill bundle. | When user explicitly asks for React/Remotion, or for a Remotion brand system. |
| **digitalsamba-toolkit** (Digital Samba, 1.2K★) | Full Remotion-based production framework — brand profiles, project lifecycle, 11 cluster skills. | When user needs templated video projects (sprint-review, product-demo) with brand profiles. |
| **hyperframes-student-kit** (nateherkai, 360★) | 12 finished Hyperframes+GSAP example projects. | Mine for animation patterns when building a new HyperFrames slot. |
| **Math-To-Manim** (HarleyCoops, 2.0K★) | Multi-LLM math/physics animation pipeline. Active. | Math diagrams, derivations, physics explainers, graph morphs. |
| **manim-skill** (Yusuke710, 54★) | Smaller Manim skill. | Only if Math-To-Manim is overkill for the slot. |

### Tier 3 — niche / supporting

| Repo | Role | When to use |
|---|---|---|
| **Claude-Video-Editor-Plugin** (danielrosehill, 2★) | Linux-native 35 skills: GPU profiling, MKV manipulation, NAS, audio (EBU R128, EQ, normalize), subtitle backends, cut-segment, deps-setup, agentic-edit wrapper, editor integration. | **Use individual sub-skills** even though the plugin as a whole has no traction. The skills are well-engineered: `burn-subtitles`, `normalize-audio`, `auto-cut-silences`, `cut-segment`, `transcode`, `render-with-profile`, `mkv-*`. |
| **Youtube-clipper-skill** (op7418, 1.9K★) | YouTube download + semantic chapters + bilingual SRT + clip. | When ingest source is a YouTube URL. |
| **ECC** (affaan-m, 187K★) | Agent harness patterns: code-reviewer, TDD skills, skill marketplace. **Community-divided** on whole-system adoption. | Borrow individual modules (e.g., code-reviewer agent template) — don't install wholesale. |
| **toolkit-landscape** (wilwaldon, 42★) | Curated index doc of the ecosystem. | Reference reading only; not invoked. |
| **video-editor-for-claude-code** (seedprod, 5★) | Cuts "thinking time" from Claude Code screen recordings. Dead. | Only if publishing demo videos of FSH sessions. |
| **VideoAgent-Stanford** (149★) | Long-form video understanding (research). | Out of scope MVP. |

### Tier 4 — Anthropic-official

| Repo | Role | When to use |
|---|---|---|
| **anthropic-skills** (Anthropic, 137K★) | Official skill catalog: `algorithmic-art`, `brand-guidelines`, `canvas-design`, `frontend-design`, `theme-factory`, `slack-gif-creator`. | When the user mentions brand work, color/theme, or visual identity. `brand-guidelines` + `theme-factory` for project intake. |
| **anthropic-claude-cookbooks** (Anthropic, 43K★) | Pattern library. | Reference when designing a new sub-agent prompt or evaluation rubric. |
| **anthropic-cwc-long-running-agents** (Anthropic, 333★) | Long-running agent patterns. | Reference for the continuous-worker loop design. |
| **anthropic-claude-agent-sdk-demos** (Anthropic, 2.4K★) | Agent shape demos (email, research, resume). | Reference for in-instance sub-agent shapes. |

## Pipeline action → skill mapping

This table is the canonical lookup for `loop-not-done.sh`'s next-action
hints and for the agent's own dispatch decisions.

| Pipeline action | Primary | Fallback | Notes |
|---|---|---|---|
| Inventory + ffprobe | inline Bash via Claude Code | — | No skill needed for this step |
| Word-level transcribe | `/opt/ml-venv/bin/python -m whisperx` (GPU) | `faster-whisper` Python API | WhisperX has built-in diarization via pyannote |
| Pack transcripts (LLM reading view) | port of `video-use/helpers/pack_transcripts.py` | — | Output: `edit/takes_packed.md` |
| Visual timeline | `Claude-Video-Editor-Plugin/skills/video-timeline/` | `video-use/helpers/timeline_view.py` | Use plugin version for project workspaces (matches our index/project model) |
| Propose strategy | inline agent reasoning + AskUserQuestion | — | Write to `docs/strategy.md`; user confirms via prompt or PR-like flow |
| Build EDL | in-instance Agent sub-agent w/ `video-use/SKILL.md` editor brief | `buttercut/skills/roughcut/` | Brief is shaped per content type (interview / launch / tutorial) |
| Extract + grade + fade per segment | port of `video-use/helpers/render.py` extract path + `grade.py` | `Claude-Video-Editor-Plugin/skills/cut-segment/` | Per-segment; never single-pass filtergraph |
| HTML/CSS overlay | `hyperframes` via `npx --yes hyperframes` in slot dir | — | One slot dir per overlay |
| React overlay | `remotion-official-skills` patterns; scaffold with `npx create-video@latest` in slot dir | — | Use only when Remotion is the simpler authoring model |
| Math overlay | `Math-To-Manim` | `manim-skill` | Render LaTeX MathTex with raw strings |
| Programmatic overlay (counters, simple cards) | PIL inline scripts per `video-use/SKILL.md` | — | Fastest path; the launch video used this |
| Overlay composite | `video-use/helpers/render.py` overlay logic | — | Enforces Hard Rule 4 (PTS shift) |
| Subtitles SRT generation | `Claude-Video-Editor-Plugin/skills/burn-subtitles/` (faster-whisper backend) | direct WhisperX call | Output: `edit/master.srt` |
| Subtitle clean-up | `Claude-Video-Editor-Plugin/skills/clean-transcription/` | — | Strip fillers, fix glossary terms |
| Audio normalize | `Claude-Video-Editor-Plugin/skills/normalize-audio/` (two-pass loudnorm) | manual ffmpeg | -14 LUFS YouTube, -23 LUFS broadcast |
| Audio analysis (LUFS check) | `Claude-Video-Editor-Plugin/skills/audio-analysis/` | manual ffmpeg | Before any normalization decision |
| Talking-head EQ | `Claude-Video-Editor-Plugin/skills/talking-head-eq/` | — | Requires `preferences.json` EQ preset |
| Auto-cut silences | `Claude-Video-Editor-Plugin/skills/auto-cut-silences/` (wraps auto-editor) | — | Useful pre-pass for lectures / talking heads |
| Render preview (720p) | `video-use/helpers/render.py --preview` | — | Must apply subtitles LAST |
| Render final | `video-use/helpers/render.py` + manifest.output_spec | `Claude-Video-Editor-Plugin/skills/render-with-profile/` | Use NVENC via `-c:v h264_nvenc` |
| GPU profile detection | `Claude-Video-Editor-Plugin/skills/profile-system/` | `nvidia-smi` direct | Run once per container restart |
| MKV ops (extract/strip/set-default tracks) | `Claude-Video-Editor-Plugin/skills/mkv-*/` | mkvmerge / mkvextract direct | No re-encode |
| Render-from-library (montage) | `Claude-Video-Editor-Plugin/skills/render-from-library/` | manual ffmpeg concat | Lossless when codecs match |
| Self-eval at cut boundaries | `video-use/helpers/timeline_view.py` per cut | — | Hard Rule: max 3 fix passes |
| NLE export FCPXML | `buttercut/lib/buttercut/fcpx.rb` (Ruby) | — | Single-track timeline only |
| NLE export FCP7/Premiere/Resolve | `buttercut/lib/buttercut/fcp7.rb` | — | xmeml v5 |
| YouTube ingest | `Youtube-clipper-skill` | yt-dlp direct | Semantic chapters as a bonus |
| Brand intake | `anthropic-skills/skills/brand-guidelines` + `theme-factory` | — | Produce a `brand.json` for the project |
| TTS (voiceover) | F5-TTS or XTTS via `agent-install` (deferred, large model weights) | — | GPU; ElevenLabs explicitly out (per user) |
| Image gen (local) | FLUX.2 Klein 4B via diffusers in `/opt/ml-venv` | — | Add to ml-venv on first need |
| Image edit (local) | Qwen-Image-Edit via diffusers | — | Add to ml-venv on first need |

## Sub-agent dispatch patterns

When the action calls for parallel work — most commonly **building
multiple animation overlays** — spawn one in-instance `Agent` per
slot via the `Agent` tool, `subagent_type: general-purpose`, with a
self-contained prompt (sub-agents have no parent context).

Each sub-agent's prompt must include (per `video-use/SKILL.md`):
1. One-sentence goal: "Build ONE animation: [spec]. Nothing else."
2. Absolute output path: `/work/<id>/edit/animations/slot_<n>/render.mp4`
3. Exact technical spec: resolution, fps, codec, pix_fmt, CRF, duration
4. Style palette as concrete RGB/hex (no "brand colors" without resolution)
5. Font path with index
6. Frame-by-frame timeline (what happens when, with easing)
7. Anti-list ("no chrome, no extras, no titles unless specified")
8. Code pattern reference (copy helpers inline; don't import across slots)
9. Deliverable checklist (script, render, verify duration via ffprobe, report back)
10. "Do not ask questions. If anything is ambiguous, pick the most obvious interpretation and proceed."

Same pattern for the editor sub-agent (build EDL) and the reviewer
sub-agent (gate state transitions).
