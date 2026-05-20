# Capability Matrix

Tracks every capability the FotoStudioH agent claims, the on-disk
evidence required to consider it "production-ready", and which skill
repo backs it.

Stage ladder for **each capability** (not the same as the per-project
pipeline ladder in ARCHITECTURE.md):

| Stage | Meaning |
|---|---|
| **missing** | No code path exists. Agent doesn't even know about this capability. |
| **state-only** | A toggle exists in manifest/settings but the engine isn't wired. |
| **engine-not-wired** | Skill repo is cloned + readable, but no caller in the FSH pipeline invokes it yet. |
| **wired-unvalidated** | Pipeline invokes it; no end-to-end test on real footage yet. |
| **production-ready** | Validated end-to-end on real footage with on-disk evidence. |

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
| Subtitle styling | engine-not-wired | force_style preset from manifest.subtitles | rendered preview shows styled subs (font, color, margin) |
| Subtitle last in chain | wired-unvalidated | `render.py` enforces order | inspect rendered output: no overlay hides any subtitle line |
| Render preview (720p) | wired-unvalidated | `render.py --preview` | `edit/preview.mp4` 1280x720, < 5min render for ≤2min source |
| Render final (delivery res) | wired-unvalidated | `render.py` default + manifest.output_spec | `edit/final.mp4` matches manifest.output_spec |
| Self-eval at cut boundaries | wired-unvalidated | timeline_view at every cut, max 3 fix iter | `.claude/state/self-eval.verdict` with PASS or detailed gap list |
| NLE export FCPXML | engine-not-wired | `agents/buttercut/lib/buttercut/fcpx.rb` | `output/final.fcpxml` opens cleanly in FCP X |
| NLE export FCP7/Premiere | engine-not-wired | `agents/buttercut/lib/buttercut/fcp7.rb` | `output/final.xml` opens in Premiere |
| NLE export Resolve | engine-not-wired | `agents/buttercut/lib/buttercut/fcp7.rb` (xmeml v5 works) | same XML; opens in DaVinci Resolve |
| TTS (local, GPU) | engine-not-wired | F5-TTS or XTTS v2 via `agent-install` | `edit/voiceover/<name>.mp3` matches script |
| Music gen (local) | missing | needs local ACE-Step alt | — |
| Watermark removal | missing | requires LTX-2-class video gen (cloud-only) | out of scope MVP |
| Talking-head (image+audio→video) | missing | SadTalker — cloud (Modal/RunPod) | out of scope MVP |
| Image gen (local) | engine-not-wired | FLUX.2 Klein 4B fits in 12GB VRAM | `edit/images/<n>.png` produced by local diffusers pipeline |
| Image edit (local) | engine-not-wired | Qwen-Image-Edit fits in 12GB VRAM | edited image at requested style |
| Multicam sync | missing | no skill in collection (Selects-only) | not viable without commercial Selects MCP |
| B-roll auto-insert | missing | no skill in collection | not viable in current set |
| Auto-cut silences | engine-not-wired | `Claude-Video-Editor-Plugin/skills/auto-cut-silences/` (wraps `auto-editor`) | timeline with silent segments removed, no clipped speech |
| GPU encode (NVENC) | engine-not-wired | ffmpeg `-c:v h264_nvenc` | `final.mp4` encoded with NVENC; 4x+ faster than libx264 |

## Out-of-scope (MVP)

- Anything requiring cloud GPU (LTX-2 22B video gen, SadTalker at full res,
  large-model dewatermark). Investor constraint: fully local IT.
- Multicam editing, B-roll matching, frame-precise (10ms) cuts —
  require Selects MCP which is closed-source commercial.

## How to update this matrix

Whenever a capability moves up the ladder, edit this file in the same
commit as the code/test that produces the evidence. The reviewer
sub-agent reads this file to verify production-ready claims.
