# Research: editorial craft + audio + platform delivery + captions + color

Background research output from a parallel agent. Five high-impact craft
+ delivery categories the fsh-agent will use *constantly*.

## The single biggest unlock

**JosiahSiegel/claude-plugin-marketplace** (37★, MIT, 2026-04, https://github.com/JosiahSiegel/claude-plugin-marketplace) — the `ffmpeg-master` plugin bundles ~30 atomic `SKILL.md` files covering categories 2/3/4/5 with concrete ffmpeg commands and platform-spec tables. Single clone replaces 5 separate research targets.

Specific files inside `ffmpeg-master/skills/`:
- `ffmpeg-audio-processing`
- `ffmpeg-noise-reduction` (afftdn + anlmdn with concrete params)
- `viral-video-platform-specs` (aspect / res / max-dur / file caps / hook windows / LUFS / safe-zones / bitrates per platform — the definitive table)
- `viral-video-hook-templates` (10 named hook patterns with timing + stop-rate metrics)
- `viral-video-animated-captions`
- `ffmpeg-captions-subtitles` (force_style ASS params, AABBGGRR colors, 24pt min, 42-char max-per-line, 1-7s window)
- `ffmpeg-kinetic-captions` + `ffmpeg-karaoke-animated-text`
- `ffmpeg-color-grading-chromakey` (lut3d, curves, colorbalance, colortemperature, HDR→SDR via zscale+tonemap=hable)
- `ffmpeg-hardware-acceleration` (NVENC h264/hevc/av1, CRF 0-40 table, +faststart, yuv420p)
- `ffmpeg-fundamentals-2025`

## Top 5 must-clones (priority order)

1. **JosiahSiegel/claude-plugin-marketplace** (the ffmpeg-master plugin) — see above.

2. **AgriciDaniel/claude-youtube** (120★, MIT, 2026-04) — Only deep-coverage YouTube long-form delivery skill set: channel audits, video SEO, retention scripts, thumbnail briefs, chapter markers, upload metadata package. 1 SKILL.md orchestrator + 14 sub-skills. Local-first; paid integrations opt-in.

3. **Audio Mixing Patterns SKILL.md** — Best-in-class LUFS-per-platform + sidechain ducking + content-type mix ratios. Transcribe from NeverSight/skills_feed aggregator into our own `/agents/fsh-audio-mixing/SKILL.md` — not clone-the-repo, copy the file with attribution.
   - Direct sidechain ducking command: `sidechaincompress=threshold=0.02:ratio=10:attack=50:release=500`

4. **AgriciDaniel/claude-shorts** (93★, MIT, 2026-05) — **reference-only** (overlaps our video-use + buttercut). Mine: `references/scoring-rubric.md` (5-dimension segment scoring), platform encoding profile table, boundary-snap algorithm. Fully local — no paid APIs.

5. **isaacrowntree/color-grade-ai** (8★, MIT, 2026-04) — **reference-only.** Read the 6-node correction-chain architecture + auto-grade workflow once. Cleanest example of LUT-as-skill but not enough alone.

## Honorable mentions / bookmark-only

- **KyaniteLabs/mcp-video** (19★, Apache-2.0, 2026-05) — 87 ffmpeg + Hyperframes tools, "local, fast, free". Worth a closer look if we ever want an MCP layer.
- **claudemarketplaces.com** — primary index (6.7K skills / 2.5K marketplaces / 840 MCPs, daily-updated). Bookmark.
- **VoltAgent/awesome-agent-skills** (22K★) — Bookmark as discovery surface.
- **louisedesadeleer/clipify** (356★, MIT) — reference-only. Read `build_ass.py` for opus-style ASS patterns. Don't clone (overlaps).

## Skip explicitly

- **hesreallyhim/awesome-claude-code** — TOC mid-reorganization. Re-check in 3 months.
- **bitwize-music-studio/claude-ai-music-skills** (198★) — Suno (paid SaaS) dependency.
- **danielrosehill/Claude-Transcription-Plugin** (0★) — Cloud-only backends.
- **rohitg00/awesome-claude-code-toolkit**, **karanb192/awesome-claude-skills**, **staruhub/ClaudeSkills** — Aggregator-of-aggregator, no original content.

## Gaps to write ourselves (no upstream)

| Skill | Source material | Effort |
|---|---|---|
| **Editorial theory** (Murch Rule of Six, Pudovkin 5 montage types, J/L/match/jump/smash cut catalog, pacing-by-content-type matrix) | Murch *In the Blink of an Eye*; no-film-school | 1 day |
| **CPS / reading-speed enforcement** (17 CPS broadcast, 20 CPS Netflix, 11 CPS Scandinavian) | Amara/EZTitles | 2h |
| **Vectorscope + waveform + skin-tone + broadcast-safe** | ffmpeg `histogram`, `vectorscope`, `waveform`, `signalstats`, `limiter` 16-235 | 1 day |
| **Two-pass NVENC + CRF trade-off matrix** | ffmpeg + NVIDIA docs | 2h |
| **Local-library music selection** (energy/BPM/mood-tag → file lookup) | original | 1 day design |
