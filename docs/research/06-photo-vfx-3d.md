# Research: photo / image / VFX / 3D skill repos

Background research output from a parallel agent. The PHOTO side of
FotoStudioH (the "Foto" in the name) — local AI photo editing, photo
composition, 3D/Blender automation, VFX, and image↔video bridges.

## Top 5 must-clones (priority order)

1. **ahujasid/blender-mcp** (21.8K★, MIT, 2026-01-23) — Canonical
   BlenderMCP. Bridges Claude/MCP to a running Blender via TCP. Has
   Sketchfab/PolyHaven/Hyper3D asset-download integrations. Battle-
   tested. Needs Blender open (use BlenderProc for headless).

2. **danielrosehill/Claude-Image-Production-Plugin** (3★, MIT,
   2026-05-03) — 15+ commands + 13 SKILL.md skills wrapping
   ImageMagick / exiftool / Pillow / libvips / oxipng-jpegoptim-mozjpeg
   / avifenc / OpenCV / CairoSVG / vtracer. Batch filters, BG removal,
   format conversion (WebP/AVIF), WB correction, skew, dedup, EXIF org,
   organisation by aspect/camera/time. **Only mature Claude-Code-native
   photo plumbing plugin** despite the 3-star count. Saves writing ~20
   SKILL.md files from scratch.

3. **RobLe3/cc-blender-skill** (4★, MIT, 2026-05-01) — Star-rule
   waiver justified by uniqueness + honest validation methodology. 30
   chain-loadable SKILL.md sub-skills (orchestrator + modeling /
   materials / lighting / cameras / rendering / animation / export /
   wireframe-to-3d / reference-to-3d / contour-to-mesh / atlas-uv-
   fitting / reference-look-calibration / quality gates). Each skill
   <500 lines with deeper references. Validated on 6 scene classes
   against Blender 5.1.1. Pairs with blender-mcp (mcp = bridge; this =
   knowledge).

4. **LingyiChen-AI/comfyui-workflow-skill** (246★, no license,
   2026-04-09) — NL → ComfyUI workflow JSON. 34 built-in templates
   (txt2img / img2img / inpaint / txt2vid / img2vid / 3D) across SD1.5,
   SDXL, SD3, FLUX, Wan2.2, HunyuanVideo, LTXV, Mochi, Cosmos. 360+
   node definitions split into 42 lazy-load files. Real SKILL.md. The
   LLM scaffolding layer over your existing diffusers stack. **Pin
   a specific commit** due to license absence.

5. **BrokenSource/DepthFlow** (1.4K★, AGPL-3.0, 2026-04-13) — Modern
   depth-aware Ken Burns. Depth-Anything depthmap + GLSL shader for
   parallax. The still→video bridge that beats flat Ken Burns. AGPL
   means think about distribution but in-house use is fine.

## Bonus must-clone (if headless renders needed)

- **DLR-RM/BlenderProc** (3.5K★, GPL-3.0, 2026-01-20) — Programmatic
  headless Blender. Solves the GUI-required gap that blender-mcp
  leaves. Useful for product shoots, environment composites, batch
  variants.

## Useful binaries (don't clone — pip install or skip)

| Repo | Stars | What | Disposition |
|---|---:|---|---|
| danielgatis/rembg | 23K | Best-in-class BG removal CLI | pip install only |
| Sanster/IOPaint | 23K | Inpaint successor to lama-cleaner | pip install + document HTTP endpoint |
| xinntao/Real-ESRGAN | 35K | 4× upscaler standard | likely covered by digitalsamba-toolkit; verify first |
| TencentARC/GFPGAN | 37K | Face restoration | pip install |
| sczhou/CodeFormer | 18K | Blind face restoration | pip install if heavy degradation |
| lllyasviel/IC-Light | 8.4K | Diffusion image relighting | **clone** — critical for studio use, no good SKILL.md exists |
| Fanghua-Yu/SUPIR | 5.5K | Photoreal restoration in the wild | reference; tight on 12GB |
| microsoft/Bringing-Old-Photos-Back-to-Life | 16K | Old-photo restoration | reference; stale |
| pq-yang/MatAnyone | 1.6K | CVPR 2025 stable video matting | reference; bridge photo→video |
| facebookresearch/sam2 | 19K | SAM2 segment-anything-video | reference; foundation for AI rotoscoping |
| sczhou/ProPainter | 6.7K | ICCV 2023 video inpainting | reference; verify digitalsamba overlap |

## Photo composition + craft — explicit gap

**Nothing strong exists.** No skill repo meets the ≥100★/fresh bar for
rule-of-thirds, golden ratio, leading lines, exposure triangle, color
harmony, lighting setups, focal-length-emotion mapping. Aesthetic-
scoring models (idealo/image-quality-assessment) are CNN scorers,
not LLM craft instruction.

**Recommendation: hand-author `photo-composition/SKILL.md`** — a
FotoStudioH-native moat using standard photography references. The
gap is real and the work is well-bounded.

## VFX — slim pickings

No mature LLM-readable VFX skill repo exists. Best primitives:
- **facebookresearch/sam2** (19K, Apache-2.0) — promptable video
  segmentation for AI rotoscoping, masking. Reference + write own
  SKILL.md wrapper.
- **sczhou/ProPainter** (6.7K) — video inpainting (object removal).
- **jiupinjia/SkyAR** (2K, no license, 2022-08) — sky replacement.
  Stale but unique.
- **NatronGitHub/Natron** (5.4K, GPL-2.0) — node compositor. Heavy.
  Skip unless concrete need.

**Recommendation: hand-author `vfx-ffmpeg/SKILL.md`** documenting
chroma-key (`colorkey`/`chromakey`), light-wrap blends, lens-flare
overlays, particle composites via ImageMagick `-composite`, SAM2-driven
masks. ffmpeg + SAM2 cover ~80%.

## Image↔Video bridge

DepthFlow is the headliner (above). Also worth knowing:
- **DepthAnything/Depth-Anything-V2** (8.1K, Apache-2.0) — depth
  foundation. DepthFlow embeds it; don't double-clone.
- **sniklaus/3d-ken-burns** (1.6K) — original paper. DepthFlow eats
  its lunch.
- **Trekky12/kburns-slideshow** (72★, MIT) — slideshow Python tool.
  Reference for code template.
- **vishh/photo-montage-remotion** (0★) — new Remotion template for
  photo montage. Reference; you already have Remotion expertise.
- **alicevision/Meshroom** (12.7K) — photogrammetry photos → 3D mesh.
  Different bridge direction. Reference only.

## Skipped explicitly

- AIGODLIKE/GenesisCore (120★) — duplicates blender-mcp.
- youichi-uda/blender-mcp-pro (15★) — too new.
- HurtzDonutStudios/ai-forge-mcp (61★) — "565 tools across
  Substance/Maya/Houdini/UE" sounds like vapor; no license.
- olive-editor/olive — no Python API for agent use.
- jeffnolan/nano-banana-photoshoot (2★) — Gemini API (paid).
