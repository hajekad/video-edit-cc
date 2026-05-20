# Research: compliance / accessibility / legal / localization layer

Background research output from a parallel agent. The non-negotiables
production-grade video work has to honor, often forgotten until late.

## Top-3 must-have-before-delivery

### 1. Music copyright check — `chromaprint` + AcoustID
- **Repo:** [acoustid/chromaprint](https://github.com/acoustid/chromaprint) (1.3K★, GPL-2.1/LGPL-2.1, Jan 2026) + `pyacoustid` wrapper.
- **Catches:** Commercial music in the MusicBrainz/AcoustID corpus that snuck in (temp tracks left in final, expired-license music, client uploaded their favorite Spotify track as "reference").
- **Cost:** ~3s per minute of audio on RTX 3080 Ti. Free AcoustID lookups. Fully local fingerprinting; lookups hit a free rate-limited public server.
- **Honest limitation:** Won't see private-label catalogs (Audible Magic). For YouTube-monetized deliverables, also test through a YouTube test channel as a sanity check.
- **Verdict:** reference-only — wrap as ~50-line script.

### 2. Face & license-plate blur — `EgoBlur`
- **Repo:** [facebookresearch/EgoBlur](https://github.com/facebookresearch/EgoBlur) (222★, Apache-2.0, May 2026, actively maintained).
- **Catches:** GDPR/privacy violations in B-roll, street footage, bystanders, document/screen PII.
- **Cost:** ~real-time on a 3080 Ti, single CLI per source clip.
- **Why this not deface:** Maintained, Apache-2.0, handles plates too, Meta-backed detection quality.
- **Verdict:** clone.

### 3. NSFW + brand-safety scan — `nsfw_model` + custom `open_clip` wrapper
- **Repos:** [GantMan/nsfw_model](https://github.com/GantMan/nsfw_model) (2.1K★, Keras, Feb 2024) — proven 5-class classifier (drawings/hentai/neutral/porn/sexy), permissive license. PLUS ~100-line wrapper on [mlfoundations/open_clip](https://github.com/mlfoundations/open_clip) accepting a list of "brand-unsafe" text prompts (e.g., "alcohol", "competitor logo X", "violence") and flagging frames with high cosine similarity.
- **Cost:** Sample ~1fps, batch through CLIP, <1 min per 10-min video.
- **Why this combo:** `nsfw_model` is binary gate with clean license. `open_clip` adds per-client negative-rules without retraining. AVOID `NudeNet` (AGPL-3.0, deal-breaker for shipped agents).
- **Verdict:** clone GantMan/nsfw_model; reference-only on open_clip (use as a dependency).

## Other categorical findings

### Privacy — voice anonymization
- **DigitalPhonetics/speaker-anonymization** (99★, GPL-3.0) — too restrictive. Pattern reference only.
- **Voice-Privacy-Challenge/Voice-Privacy-Challenge-2024** (62★) — eval metrics reference.
- **For 95% of "make the witness unrecognizable" use cases:** a 30-line ffmpeg + librosa pitch/formant shift wrapper.

### Accessibility — audio description
- **microsoft/ai-audio-descriptions** (43★, MIT, Feb 2026) — Microsoft's own AD pipeline: scene-describe → find silences → fit description into gaps → render. Below the 50-star threshold but **nothing else open-source does this end-to-end**. **Clone.**

### Accessibility — color-blindness simulators
- **joergdietrich/daltonize** (Apache-2.0) — simulates protanopia/deuteranopia/tritanopia + corrects. **Reference-only**, wrap as ~40-line `color_safety_check.py`.

### Accessibility — dyslexia-friendly typography
- **OpenDyslexic font** (SIL OFL) — Bundle as asset. Research evidence for actual benefit is mixed (Rello & Baeza-Yates 2013). The hard wins are min-16px font, sans-serif, 1.5+ line height, no full-justify — which are codeable WCAG rules.

### Accessibility — sign language overlay
- **Honest gap. No usable OSS in 2026.** Don't promise this capability.

### Accessibility — caption validation
- **Comcast/caption-inspector** (94★, Apache-2.0) — CEA-608/708 reference decoder. Reference for broadcast-grade deliverables.

### Localization — translation + dubbing
- **Huanshere/VideoLingo** (17.1K★, Apache-2.0, Mar 2026) — **clone.** Subtitle cutting + translation + alignment + dubbing in one pipeline. LLM-driven "translate-reflect-adaptation" loop handles idioms/cultural adaptation automatically.
- **Kedreamix/Linly-Dubbing** (3.2K★, Apache-2.0) — **clone if both wanted.** Heavier voice/lip-sync side (Demucs/UVR5 + CosyVoice/GPT-SoVITS/XTTS + Linly-Talker for lip-sync). Strong Chinese support. Complementary to VideoLingo.
- **Softcatala/open-dubbing** (393★, Apache-2.0) — reference-only fallback.
- **machinewrapped/llm-subtrans** (600★) — reference-only. Lighter than full VideoLingo when you only need translation.
- **coqui-ai/TTS** / **idiap/coqui-ai-TTS** — reference-only (it's the XTTS-v2 model VideoLingo uses). Use the idiap fork (active); original is frozen.

### Content moderation pipelines
- **fcakyon/content-moderation-deep-learning** (397★, MIT, Feb 2026) — **clone.** Multi-modal moderation reference catalog (which model for which task). Effectively a meta-skill.

### Violence detection
- **Honest gap. No production-grade OSS option in 2026.** CLIP-based concept-prompting (using "fistfight", "weapon pointed at person") is the pragmatic substitute.

## Wrapper-script opportunities (no clone needed, ~30-100 LOC each)

- `face_blur` — EgoBlur CLI wrapper, ~30 lines
- `music_copyright_gate` — `fpcalc | acoustid lookup` flow, ~50 lines
- `color_safety_check` — daltonize over key frames, alert on contrast loss, ~40 lines
- `flash_rate_audit` — ffmpeg histogram + delta-luma vs 3Hz limit, ~60 lines
- `on_screen_text_pii` — tesseract OCR + regex on burned-in text, ~80 lines
- `brand_safety_clip_scan` — open_clip + concept-prompt list, ~100 lines

## Honest gaps to tell the user

1. **"ContentID-grade" risk prediction** — paid services only. Chromaprint + AcoustID is the legitimate local equivalent but won't see private-label catalogs.
2. **Automatic sign language overlay** — no usable OSS in 2026.
3. **Violence detection** — only research code. CLIP concept-prompting is the workaround.
4. **Cultural adaptation playbook** — no code exists; build as SKILL.md (locale-specific date/time/currency/measurement/idiom/gesture/color cheatsheets).
5. **Holistic WCAG 2.2 video conformance checker** — caption-inspector handles broadcast captions, but the full WCAG-2.2 video checklist (audio description present, contrast on burned-in text, flash-rate under 3Hz) doesn't exist as a single tool. Each individual check is trivial — build the bundle.

## License caveats

- **NudeNet (AGPL-3.0)** — deal-breaker for shipped agents. Use locally as a CHECK only; don't redistribute. GantMan/nsfw_model is the cleaner license for embedded use.
- **DigitalPhonetics/speaker-anonymization (GPL-3.0)** — too restrictive for embed; reference-only.
- **Linly-Dubbing, VideoLingo, EgoBlur** — all Apache-2.0; clean for shipped use.
