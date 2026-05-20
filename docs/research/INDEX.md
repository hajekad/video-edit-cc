# Research Index

Output from parallel research agents on the FotoStudioH skill / context
landscape. Read when the project demands a capability not yet in
`/docs/CAPABILITY_MATRIX.md` — these reports show what's available
externally and what we'd have to hand-author.

## Files

| # | File | What it covers |
|---|---|---|
| 01 | [marketing-biz-skills.md](./01-marketing-biz-skills.md) | How to translate vague business/marketing/HR prompts into concrete cuts, hooks, on-screen text, brand voice. Top clones: coreyhaines31/marketingskills (29.5K★), anthropics/knowledge-work-plugins (12.3K★, selective subdirs), alirezarezvani/claude-skills (15.5K★). |
| 02 | [craft-and-delivery.md](./02-craft-and-delivery.md) | Editorial craft, audio production, platform delivery, captions, color. Biggest unlock: JosiahSiegel/claude-plugin-marketplace (ffmpeg-master plugin, ~30 atomic SKILL.md files). |
| 03 | [domain-patterns.md](./03-domain-patterns.md) | Per-domain video editing patterns (wedding, doc, tutorial, music video, sports, real-estate, vlog, kids, corporate, news). Single best source: OpenMontage `pipelines/documentary-montage/edit-director.md` (AGPL — paraphrase, don't fork). Honest gaps: wedding/sports/real-estate/kids/news — hand-author. |
| 04 | [harsh-reviewer.md](./04-harsh-reviewer.md) | How to make the `issue-state-review.sh` reviewer actually push back instead of rubber-stamping. 24-item rubric, 9 bias-mitigation techniques, recommended prompt diff. |
| 05 | [compliance-accessibility.md](./05-compliance-accessibility.md) | Copyright (chromaprint+AcoustID), privacy/face-blur (EgoBlur), accessibility (Microsoft AD, daltonize, OpenDyslexic), localization (VideoLingo, Linly-Dubbing), brand-safety (nsfw_model + open_clip). |
| 06 | [photo-vfx-3d.md](./06-photo-vfx-3d.md) | Photo (the "Foto" side of FotoStudioH): local AI photo editing, 3D/Blender automation, VFX, image↔video bridges. Top: ahujasid/blender-mcp (21.8K★), danielrosehill/Claude-Image-Production-Plugin, RobLe3/cc-blender-skill, LingyiChen-AI/comfyui-workflow-skill, BrokenSource/DepthFlow. |

## Cross-cutting must-clones (top 10 from across all reports)

1. **JosiahSiegel/claude-plugin-marketplace** (ffmpeg-master plugin, 37★) — craft + delivery + captions + color in one repo
2. **coreyhaines31/marketingskills** (29.5K★) — marketing/business interpretation
3. **ahujasid/blender-mcp** (21.8K★) — 3D bridge (Blender via MCP)
4. **Huanshere/VideoLingo** (17.1K★) — localization / dubbing in one pipeline
5. **alirezarezvani/claude-skills** (15.5K★) — selective: video-content-strategist, marketing-strategy-pmm, marketing-context
6. **anthropics/knowledge-work-plugins** (12.3K★, selective subdirs) — brand-voice + campaign + sales + PM + design
7. **GantMan/nsfw_model** (2.1K★) — brand-safety baseline (clean license, vs AGPL NudeNet)
8. **BrokenSource/DepthFlow** (1.4K★) — modern depth-aware Ken Burns for still→video
9. **facebookresearch/EgoBlur** (222★) — privacy / face + license-plate blur
10. **LingyiChen-AI/comfyui-workflow-skill** (246★) — NL → ComfyUI workflow generator with 34 templates

Bonus tier (smaller but uniquely-positioned):
- **AgriciDaniel/claude-youtube** (120★) — only deep-coverage YouTube long-form delivery skill set
- **microsoft/ai-audio-descriptions** (43★) — Microsoft's OSS audio-description pipeline (no other OSS does this)
- **RobLe3/cc-blender-skill** (4★ — waiver justified) — 30 Blender SKILL.md sub-skills
- **danielrosehill/Claude-Image-Production-Plugin** (3★ — waiver justified) — 13 SKILL.md photo skills, only mature local-photo Claude plugin

## Cross-cutting reference-only (high-value but don't clone wholesale)

- **OpenMontage** (AGPL — paraphrase) — single best editorial-craft source
- **agents/ECC/agents/code-reviewer.md** (already cloned) — lift for harsh-reviewer structure
- **acoustid/chromaprint + pyacoustid** — wrap as ~50-line script
- **GantMan/nsfw_model + open_clip** — brand-safety scanning

## High-leverage gaps to hand-author

| Skill | Why it doesn't exist | Effort |
|---|---|---|
| Editorial theory (Murch / Pudovkin / cut-type catalog) | Nobody packaged it | 1 day |
| CPS reading-speed enforcement | Standards exist (Netflix 20 CPS, broadcast 17 CPS); no skill | 2h |
| Vectorscope/skin-tone/broadcast-safe | ffmpeg filters exist; no skill | 1 day |
| Wedding / sports / real-estate / kids / news domain SKILL.md | Ecosystem gap | 1 day each |
| Funnel-stage (TOFU/MOFU/BOFU) classifier | No video-specific version | 4h |
| Cultural adaptation playbook | No code exists; pure content | 1 day |
| Holistic WCAG 2.2 video conformance checker | Comcast caption-inspector is broadcast only | 1 day script |

## How the in-container agent should use these

Don't read all five reports at the start of every project. Triage
based on the user's prompt:

- **Vague marketing/biz prompt** → read 01 first
- **Mention of "make it feel like X" / cuts/pacing/look** → read 02 + 03 for that domain
- **Pre-delivery (about to flip `stage: delivered`)** → read 05 for the three must-checks
- **About to flip `status:` or `stage:` on an issue** → 04 will already be partly applied via the hook

Reports are detailed; they substitute for an external search when the
agent can't reach GitHub. Don't re-research from scratch.
