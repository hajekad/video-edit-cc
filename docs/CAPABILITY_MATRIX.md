# Capability Matrix

**Descriptive tracker, not a refusal surface.** This file records the
current wiring state of every capability. It does NOT define what the
agent may promise to the user — the agent promises the full brief and
wires what's missing per `/docs/HARNESS_SELF_EXTENSION.md` §
"Promise, then wire". A row at `engine-not-wired` is a task list
entry, not a "can't do."

Tracks every capability the video-edit-cc agent supports, the on-disk
evidence required to consider it "production-ready", and which skill
repo backs it.

Stage ladder for **each capability** (not the same as the per-project
pipeline ladder in ARCHITECTURE.md):

| Stage | Meaning | Agent response when brief calls for it |
|---|---|---|
| **missing** | No code path exists in repo. | Install / clone / build the minimum that satisfies the brief. `agent-install`, `agent-pip-install`, `git clone <repo> /agents/<name>/`. Then proceed. |
| **state-only** | A toggle exists in manifest/settings but the engine isn't wired. | Wire the engine in `/agents/fsh-tools/<name>` or as a step in the relevant slash command. Then invoke. |
| **engine-not-wired** | Skill repo is cloned + readable, but no caller in the FSH pipeline invokes it yet. | Author the caller, invoke, update this matrix to `wired-unvalidated` in the same change. |
| **wired-unvalidated** | Pipeline invokes it; no end-to-end test on real footage yet. | Invoke. Validate on real footage. Promote to `production-ready` when evidence lands. |
| **production-ready** | Validated end-to-end on real footage with on-disk evidence. | Invoke per SKILL_ROUTING.md. |

**Hard refusal is reserved for**: hardware-physical (LTX-2 doesn't
fit in 12 GB VRAM), paid-only without user authorization, hard
classifier blocks that survive single-URL fetch + drop-in scaffold,
user explicitly forbade it, distribution-licensing for public
deliverables without license proof. Document the refusal in
`docs/issues/` with the specific reason — never a vague "out of
scope."

| Capability | Stage | Primary skill | Evidence required for production-ready |
|---|---|---|---|
| Ingest local folder | wired-unvalidated | scaffolder + `loop-not-done.sh` | `manifest.inputs[]` built from ffprobe on `/assets/<n>/raw/*` |
| Ingest single file | wired-unvalidated | same | same |
| Ingest zip | engine-not-wired | needs `unzip` in baseline + scaffolder branch | `manifest.inputs[]` includes extracted files; original zip preserved |
| Ingest YouTube URL | engine-not-wired | `agents/Youtube-clipper-skill/` + yt-dlp | URL written to `manifest.inputs[].source_url`; download lands in raw/ |
| Word-level ASR | wired-unvalidated | WhisperX in `/opt/ml-venv` | `edit/transcripts/<name>.json` with `words[]` array (start, end, text) |
| Speaker diarization | wired-unvalidated | pyannote.audio via WhisperX | `words[].speaker` populated; speaker count matches manifest hint |
| Packed transcript (LLM reading view) | wired-unvalidated | port of `video-use/helpers/pack_transcripts.py` | `edit/takes_packed.md` with phrase-level lines |
| Visual timeline (decision-point frames) | wired-unvalidated | `Claude-Video-Editor-Plugin/skills/video-timeline/` OR `video-use/helpers/timeline_view.py` | folder of low-res JPEGs + `timeline.md` index |
| Strategy proposal + user confirm | wired-unvalidated | `/plan` slash command + reviewer sub-agent | `docs/strategy.md` exists, `manifest.strategy.approved == true` |
| EDL build (multi-take selection) | wired-unvalidated | editor sub-agent w/ `video-use/SKILL.md` brief | `edit/edl.json` valid; every range snaps to word boundaries |
| Per-segment cut extract | wired-unvalidated | `video-use/helpers/render.py` per-range extract | files in `edit/clips_graded/` match `edl.ranges.length` |
| Color grade (ASC CDL style) | wired-unvalidated | `video-use/helpers/grade.py` | per-segment grade applied during extract (not post-concat) |
| 30ms audio fades at cuts | wired-unvalidated | `render.py` afade filter chain | inspect first/last 30ms of each segment for non-pop |
| Overlay: HTML → video | engine-not-wired | `agents/hyperframes/` | `edit/animations/slot_*/render.mp4` from HyperFrames pipeline |
| Overlay: React → video | engine-not-wired | `agents/remotion-official-skills/` + `agents/digitalsamba-toolkit/` | Remotion-rendered MP4 in slot dir |
| Overlay: Math/Manim | engine-not-wired | `agents/Math-To-Manim/` or `agents/manim-skill/` | Manim-rendered MP4 in slot dir |
| Overlay: PIL programmatic | engine-not-wired | `video-use/SKILL.md` PIL pattern (inline scripts) | PNG sequence + ffmpeg-composed MP4 in slot dir |
| Overlay composite (PTS-shifted) | wired-unvalidated | `render.py` overlay logic | rendered composite shows overlays at correct time, not source-time |
| Subtitle generation (whisper) | wired-unvalidated | `Claude-Video-Editor-Plugin/skills/burn-subtitles/` | `edit/master.srt` valid |
| Subtitle styling | wired-unvalidated | `/opt/claude-config/tools/burn-subtitles` (drawtext) + delivery-presets safe_zone | rendered preview shows styled subs at correct y-anchor for the platform |
| Subtitle last in chain | wired-unvalidated | `burn-subtitles` is a post-render pass after `render.py --no-subtitles` | inspect rendered output: no overlay hides any subtitle line |
| Subtitle safe-zone per platform | wired-unvalidated | `delivery-presets.json :: presets.<id>.safe_zone` + `burn-subtitles --preset` | subtitle y-anchor stays clear of platform UI bands (Reels bottom-20%, TikTok bottom-25%, etc.) |
| Render preview (720p) | wired-unvalidated | `render.py --preview` | `edit/preview.mp4` 1280x720, < 5min render for ≤2min source |
| Render final (delivery res) | wired-unvalidated | `render.py` default + manifest.output_spec | `edit/final.mp4` matches manifest.output_spec |
| Self-eval at cut boundaries | wired-unvalidated | timeline_view at every cut, max 3 fix iter | `.claude/state/self-eval.verdict` with PASS or detailed gap list |
| NLE export FCPXML | engine-not-wired | `agents/buttercut/lib/buttercut/fcpx.rb` | `output/final.fcpxml` opens cleanly in FCP X |
| NLE export FCP7/Premiere | engine-not-wired | `agents/buttercut/lib/buttercut/fcp7.rb` | `output/final.xml` opens in Premiere |
| NLE export Resolve | engine-not-wired | `agents/buttercut/lib/buttercut/fcp7.rb` (xmeml v5 works) | same XML; opens in DaVinci Resolve |
| TTS (local, GPU) | engine-not-wired | F5-TTS or XTTS v2 via `agent-install` | `edit/voiceover/<name>.mp3` matches script |
| Music gen (local) | missing | needs local ACE-Step alt | — |
| Watermark removal | missing — hard refusal | requires LTX-2-class video gen (>12GB VRAM, cloud-only) | hardware-physical refusal per § Hard refusals; propose local-fits alternative (light-wrap masking, manual crop) |
| Talking-head (image+audio→video) | missing — hard refusal | SadTalker / live portrait — cloud-only at full res | hardware-physical refusal; propose static-image + Ken Burns + VO instead |
| Image gen (local) | engine-not-wired | FLUX.2 Klein 4B fits in 12GB VRAM | `edit/images/<n>.png` produced by local diffusers pipeline |
| Image edit (local) | engine-not-wired | Qwen-Image-Edit fits in 12GB VRAM | edited image at requested style |
| Multicam sync | missing | best OSS = `agents/PySceneDetect` + audio-waveform align; closed-source commercial (Selects MCP) is paid-only | wire OSS path via timecode + audio-fingerprint align; refuse only if user demands frame-precise sub-10ms which truly needs Selects |
| B-roll auto-insert | missing | best OSS = transcript-keyword × thumbnail-similarity search across `raw/`; no canonical skill yet | author `/agents/fsh-tools/broll-suggest` when first project needs it; wire from there |
| Auto-cut silences | engine-not-wired | `Claude-Video-Editor-Plugin/skills/auto-cut-silences/` (wraps `auto-editor`) | timeline with silent segments removed, no clipped speech |
| GPU encode (NVENC) | engine-not-wired | ffmpeg `-c:v h264_nvenc` | `final.mp4` encoded with NVENC; 4x+ faster than libx264 |
| Brief interpretation (auto-derive platform/audience/brand) | wired-unvalidated | `/docs/BRIEF_INTERPRETATION.md` + `/inventory` three-pass read | `manifest.brief_intent.derived == true` with WHY lines for platforms / audience / brand / delivery_pattern |
| Delivery preset routing | wired-unvalidated | `/opt/claude-config/delivery-presets.json` + scaffold/render readers | `manifest.delivery.preset` set; render honors width/height/fps/codec/loudness from preset |
| Two-variant delivery (internal_review + platform_clean) | wired-unvalidated | `/opt/claude-config/tools/build-variants` + manifest.delivery.variants[] | `_INTERNAL_REVIEW.mp4` (music baked) + `_CLEAN_FOR_UI_MUSIC.mp4` (no music stem) both present; ffprobe confirms music absence in clean variant |
| Music workflow (royalty-free, internal-reference, baked-licensed) | wired-unvalidated | `agents/fsh-royalty-free-music` + `/music` slash command + `agents/fsh-music-mood-bridge` | `manifest.music.mode` matches artifact lifecycle; music_rights.md and music_cues.md both present |
| Pitch-music fetch (yt-dlp + fair-use-for-proposal) | wired-unvalidated | `/opt/claude-config/tools/pitch-music-fetch` | actual mp3 in `/work/<slug>/edit/music/`; manifest.music.source = "yt-dlp-fetch"; license_status = "pitch-fair-use"; distribution_allowed = false |
| PITCH PREVIEW watermark on internal_review | wired-unvalidated | `build-variants` auto-applies when manifest.music.source = "yt-dlp-fetch" | output `_INTERNAL_REVIEW.mp4` shows persistent yellow top-banner + cycling center "INTERNAL REVIEW ONLY" overlay |
| Trend-scout (peer-brand audio recon) | wired-unvalidated | `/opt/claude-config/tools/trend-scout` + `/opt/claude-config/seed_trends.yaml` | `edit/music/trend_candidates.json` with ranked candidates from TikTok Creative Center + curated seed |
| Music cues sheet (timecodes for IG-style add-music-in-UI) | wired-unvalidated | `/opt/claude-config/tools/music-cues-template` | `docs/music_cues.md` with in/duck/swell/tail timecodes (output-timeline) + replacement-track guide |
| Audience persona matching | wired-unvalidated | `agents/fsh-music-mood-bridge/personas.yaml` (17+ personas including B2B-industrial bands) | `manifest.audience_persona` set; persona key found in yaml or added with rationale |
| Brand asset retrieval (official sources only) | wired-unvalidated | `agents/fsh-brand-assets/` skill + `/inventory` automatic-research pass | `manifest.brand.logo_path` + `branding/source.md` audit trail with official URL + timestamp |
| Drop-in scaffold (when classifier blocks fetch) | wired-unvalidated | `/opt/claude-config/tools/dropin-scaffold` | `/assets/<id>/<asset>/README.md` + `/work/<slug>/edit/add_<asset>.py` merge script + `manifest.<asset>.pending_dropin = true` |
| Variant build (internal_review + platform_clean + platform_final routing) | wired-unvalidated | `/opt/claude-config/tools/build-variants` | per-variant outputs with correct suffix and music-mode-aware audio handling |

## Hard refusals (the only honest "can't")

These are the limits that no self-extension can route around without
breaking an explicit user constraint. Everything outside this list
is a task, not a refusal.

- **Cloud-GPU-only models** (LTX-2 22B video gen, SadTalker at full
  res, large-model dewatermark) — the architectural constraint is
  "fully local IT" per investor mandate. The agent does not spin up
  Modal / RunPod / cloud GPU. If the brief truly requires one of
  these, surface it and propose a local-fits alternative; do not
  silently substitute.
- **Closed-source commercial-only paths** without paid auth (Selects
  MCP for multicam, paid sync libraries for distribution) — same
  shape. Propose the local-fits alternative.
- **Paid-API spending** without explicit user authorization — the
  investor constraint is also "no paid APIs". `agent-install` and
  `agent-pip-install` are free-software-only.
- **Distribution-licensing for public deliverables** without license
  proof on file at `manifest.<asset>.license_proof_path`.
- **User explicitly forbade it** in `prompt.txt` or chat.

For everything else — `missing`, `state-only`, `engine-not-wired` —
the agent's response is to wire it. See `/docs/HARNESS_SELF_EXTENSION.md`.

## How to update this matrix

Whenever a capability moves up the ladder (`engine-not-wired` →
`wired-unvalidated` → `production-ready`), edit this file in the SAME
change as the code that produces the evidence. The reviewer sub-agent
reads this file to verify production-ready claims. New capabilities
get appended as new rows at the moment they're authored — don't wait
for a "later cleanup pass."
