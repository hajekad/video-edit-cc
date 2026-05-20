# Research: domain-specific video editing pattern libraries

Background research output from a parallel agent. Hunting per-domain
vocabulary (wedding, doc, tutorial, music video, sports, real-estate,
vlog, kids, corporate, travel, podcast, news) that maps a vague brief
to concrete editing approach.

## Headline finding

**The ecosystem has consolidated around generic pipeline repos
(OpenMontage, video-use, buttercut, FireRed-OpenStoryline) rather than
per-vertical skill repos.** Almost nobody published a `wedding/SKILL.md`
or `real-estate/SKILL.md`. The fsh-agent has to OWN the domain
vocabulary layer because nobody else packaged it cleanly.

## Top 5 most-impactful additions

### 1. Vlog / personal / lifestyle
- **OpenMontage `skills/creative/short-form.md`** — single best vlog-content reference. 20-40 cuts/min, "visual change every 1-3s", 120-140 BPM energetic / 90-110 explainer, "no silent intro — music starts immediately", 42px bold sans captions, 30 chars/line max, 2 lines max, word-by-word highlight, "80% watch without sound."
- License: **AGPL-3.0** → reference-only (paraphrase under attribution; don't fork).

### 2. Tutorial / screencast
- **OpenMontage `skills/creative/screen-recording.md` + `pipelines/screen-demo/`** — concrete numbers: record 4K → 1080p deliver, 1.5-2x code zoom with 0.8s ease-in-out, cursor 1.5-2x with color ring, "Remove all pauses > 1.5s unless deliberate", IDE 20px min / dark / hide minimap, -16 LUFS, **show-then-explain** doctrine.

### 3. Interview / podcast (video)
- **luoyuweidu1/podcastcut-skills** (42★, no license, 2026-03-17) — four-stage workflow (transcription / content-edit / rough-cut / fine-cut / final polish). 98.8% speaker-diarization claim. License absence = reference-only.
- **OpenMontage `pipelines/podcast-repurpose/`** — full executive-producer + 6-director pipeline.
- **op7418/Video-Wrapper-Skills** (292★, no license, 2026-02-10) — Chinese-first variety-show overlays + lower-thirds w/ AI subtitle analysis. Reference-only for lower-third prose patterns.

### 4. Documentary
- **OpenMontage `skills/pipelines/documentary-montage/edit-director.md`** — **the single best domain file found in this entire research**: hold-times by tone (elegiac 4.0s base, urgent 1.2s), narrative-sequence-over-metrics rule, archival/register continuity (mixed-era footage uniform-cropping + LUT), "music is a timing grid you cut TO, not a sweetener" doctrine.
- AGPL-3.0 license caveat — paraphrase under attribution, don't wholesale-fork.
- **FireRedTeam/FireRed-OpenStoryline** (2,712★, Apache-2.0, 2026-05-07) — secondary; has `default_editing_workflow_skill/`, `speech_rough_cut_skill/`, `subtitle_imitation_skill/`. Chinese-first docs.

### 5. Corporate / explainer / B2B
- **OpenMontage `pipelines/explainer/`** — most complete pipeline in the ecosystem (9 directors: executive-producer through publish-director with proposal/research stages).
- Already-cloned **digitalsamba-toolkit** overlaps significantly; explainer-pipeline is the OpenMontage angle on the same problem.

## Other domains — explicit gaps

- **Wedding** — no direct hit. Borrow `cinematic.md` + `storytelling.md` from OpenMontage. StudioBinder shot list (referenced from `adammakesfilm/creative-resources`, 73★, CC0) for shot taxonomy. **Hand-author `wedding/SKILL.md`.**
- **Sports** — all hits are research code / camera-shake-heuristic toys. **Hand-author.** Conventions to encode: slow-mo handling, replay framing, score-graphic templates, fast-motion ramping.
- **Real estate / property** — only SaaS pitches surfaced. **Hand-author.** Conventions: drone establishing → exterior wide → entry → kitchen/living first, master bed, baths last; VO 130-150 WPM; music 90-110 BPM lifestyle; 16:9 horizontal MLS / 9:16 vertical IG; before/after staging dissolves.
- **Kids / family** — no hits (the education-skills repo found is curriculum design, not entertainment video). **Hand-author.** 1-2s shot durations, high saturation, music 110-130 BPM major-key, avoid jump-scares / sudden loudness.
- **News / journalism** — `ebu/awesome-broadcasting` (1,724★) is broadcast-tech delivery specs, not editing. **Hand-author `news/SKILL.md`.** Conventions: inverted-pyramid, VO/SOT/NATSOT, lower-third "name + role + outlet", 90-120 WPM narration, b-roll-shows-what-narrator-says, ethical framing.
- **Music video** — `Merserk/BeatSync-Engine` (15★, AGPL-3.0, 2026-05-08) has BPM/kick/clap/hi-hat cut-decision logic. Extract the decision framework into `/reference/music-video-beats.md`; don't clone the codebase.
- **Travel** — no specific repo. Closest is `isaacrowntree/color-grade-ai` for LUT continuity across time-of-day. Hand-author thin SKILL.md referring out.

## Cross-cutting auxiliary

- **awesome-genmedia/skills** (12★) — reference-only for SKILL.md layout convention.
- **ad-si/awesome-video-production** (47★) — reference-only, surface link.
- **adammakesfilm/creative-resources** (73★, CC0) — reference-only for craft templates (shot-lists, contracts).
- **HKUDS/ViMax** — research-grade, skip.

## License caveat — OpenMontage AGPL-3.0

Borrowing prose verbatim from OpenMontage into FotoStudioH triggers
copyleft obligations. The safer path is **paraphrase under attribution**
into our own `/agents/fsh-<domain>/SKILL.md` files — that way the prose
becomes original work derived from public ideas, and we keep our own
distribution rights clean. Treat OpenMontage as authoritative
*content reference*, not a code dependency.
