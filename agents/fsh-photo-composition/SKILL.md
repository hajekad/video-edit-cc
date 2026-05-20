---
name: fsh-photo-composition
description: Photo composition and visual-craft theory. Rule of thirds, golden ratio, leading lines, color harmony, exposure triangle, focal-length-emotion mapping, lighting setups. Use when critiquing or generating image compositions, picking thumbnail frames, designing brand visuals, evaluating AI-generated images, or judging whether a frame "works." Read this before the photo work in any project where stills are part of the deliverable (FotoStudioH does photo too).
version: 1.0.0
---

# Photo Composition — Visual Craft Theory

The research surveyed every public OSS skill for photo composition theory.
**Nothing exists at this depth.** This file is the FotoStudioH-native
distillation of photo composition craft, oriented toward an agent that
must JUDGE images (poster-frame picks, thumbnail selection, AI-generated
image critique) and GUIDE the generation of new ones.

## The four composition primitives

### Rule of thirds
Divide the frame into a 3×3 grid. Place key subjects on the four
intersection points OR along the four grid lines. The eye reads the
image faster than centered composition. **Default for any non-symmetric
subject.**

### Golden ratio / golden spiral (φ ≈ 1.618)
Used by classical photography and cinematography. The eye traces a
logarithmic spiral from the outer edge inward to the focal point. **Use
when composing portraits with a single dominant subject; rule of
thirds for everything else.**

### Leading lines
Compose so a geometric line (road, railing, river, light beam) draws
the eye from frame edge to subject. Horizontal lines suggest calm;
vertical lines suggest power; diagonal lines suggest motion or
instability.

### Symmetry / centering
Reserved for: dignified institutional moments, architecture, deliberate
formality, character-direct-to-camera. Symmetric composition has gravity
— use it when the moment demands gravity, not as default.

## Exposure triangle (the only three variables that matter)

| Variable | Effect on image | Trade-off |
|---|---|---|
| **Aperture** (f-stop) | Depth of field. Lower f-number = shallower DOF, bokeh. Higher = everything sharp. | Diffraction softens past f/16. |
| **Shutter speed** | Motion blur. 1/250s+ freezes action. 1/15s and slower introduces blur. | Slower needs steadier hand or tripod. |
| **ISO** | Sensor sensitivity. Higher = brighter image at the cost of noise. | Modern sensors clean to ISO 6400; degrades fast past. |

For agent-generated content via diffusers / FLUX.2 / Qwen-Image-Edit:
specify "shallow depth of field at f/1.8" or "sharp throughout at f/11"
in prompts when the depth target matters.

## Focal-length-emotion mapping

The lens IS the emotion. Specify focal length in image prompts; ask for
specific lens behaviors.

| Focal length | Emotional read | Use for |
|---|---|---|
| **14-24 mm** (ultrawide) | Dramatic, distorting, intimate or vast | Establishing shots, architecture, dramatic perspective. Distorts faces — avoid for portraits. |
| **24-35 mm** (wide) | Environmental, immersive, present | Documentary, environmental portrait, run-and-gun. |
| **35-50 mm** (normal) | Natural, observational, neutral | Documentary interview, everyday composition. Closest to human eye. |
| **50-85 mm** (short tele) | Intimate, flattering, focused | Portraits, intimate moments. 85mm is THE portrait length. |
| **85-135 mm** (portrait tele) | Beautiful, isolated, idealized | Portrait, fashion. Flatters facial features (no distortion). |
| **135-200 mm** (tele) | Compressed, voyeuristic, distant | Sports, wildlife, candid. Compresses background to subject. |
| **300+ mm** (super-tele) | Surveillance, abstracted | Sports, distant wildlife. Rarely used in narrative. |

## Color harmony

When critiquing or generating brand visuals, check color relationships
against these schemes:

- **Complementary** (opposite hues on the wheel) — high contrast,
  vibrant. Orange/teal is the cinema cliché for a reason: it makes skin
  pop. Use sparingly.
- **Analogous** (adjacent hues) — harmonious, calm. Sunset/dawn palettes.
- **Triadic** (three hues at 120°) — playful, energetic. Common in
  kids' content, branding.
- **Monochromatic** (one hue, varied saturation/value) — moody, unified.
  Documentary, fashion editorial.
- **Split-complementary** (one + two adjacent to its opposite) — high
  visual interest without complementary's intensity.

When generating brand visuals from `anthropic-skills/brand-guidelines`:
**always** check the brand palette against one of these schemes; flag
if the brand violates harmony (it might be intentional, but document
the violation).

## Lighting taxonomy

| Setup | Look | Common use |
|---|---|---|
| **Three-point** (key + fill + back) | Standard, controlled, "interview" | Talking-head, corporate, commercial portrait |
| **Rembrandt** (45° key, triangle of light on far cheek) | Painterly, classical, dignified | Portrait, period drama |
| **Loop** (key 30-45°, subtle shadow under nose) | Flattering, modern, soft | Modern portrait, fashion |
| **Butterfly / Paramount** (key directly in front + above) | Glamorous, idealized, Old Hollywood | Beauty, fashion |
| **Split** (key at 90°, half face in shadow) | Dramatic, character | Noir, character study |
| **Backlight / rim** (key behind subject) | Silhouette or rimlight halo | Mysterious, romantic, hero |
| **Practical-only** (lamps, screens, windows in frame) | Naturalistic, documentary | Vlog, run-and-gun, observational doc |
| **Available light** (existing ambient only) | Imperfect, true | Photojournalism, candid |

When the strategy doc says "cinematic," default to three-point or
Rembrandt; "documentary" implies practical-only or available light;
"vlog" usually means available light + window key.

## Critique checklist (every image before delivery)

For any frame the agent picks (thumbnail, social cut poster-frame, AI-
generated image, brand visual), evaluate against these six dimensions:

1. **Subject placement** — does it follow rule of thirds, golden, or
   symmetry deliberately? Not "drift to center by default."
2. **Eye-trace** — where does the viewer's eye go first, second, third?
   Trace it. If it gets lost, recompose.
3. **Lighting direction** — is the key light deliberate? Does it model
   the subject (depth/dimension) or flatten it?
4. **Color** — is the palette harmonious? If not, is the dissonance
   intentional?
5. **Negative space** — empty frame area should be doing work
   (separating subject, balancing weight, breathing room). Random empty
   space is dead space.
6. **Frame edges** — nothing important kissed by the edge; no awkward
   crops at necks/wrists/ankles; nothing tangent to subject (a tree
   "growing out of" a head).

If 2+ fail, reject the frame. For AI-generated images, regenerate with
a tighter prompt addressing the failure (e.g., "rule of thirds, subject
on left third, eye-line tracing right" if eye-trace failed).

## Lens choice for photo+video deliverables

When delivering mixed stills + motion from the same shoot:
- **35mm or 50mm prime** is the most flexible — works for both
- **24-70mm zoom** is the run-and-gun standard
- **85mm prime** if portraits dominate
- Use focal length 24-35mm at wide aperture (f/1.8-2.8) for
  documentary-style stills that complement vlog-style video

## Cross-references

- Brand-aware generation: `anthropic-skills/brand-guidelines`, `theme-factory`
- Color theory in video grade: `agents/video-use/SKILL.md` § Color grade
- AI image generation: `agents/digitalsamba-toolkit/tools/flux2.py`,
  `image_edit.py`, `upscale.py`
- ComfyUI workflows: `agents/LingyiChen-AI/comfyui-workflow-skill` (when added)
- Photo enhancement primitives (rembg / IOPaint / IC-Light) referenced
  in `docs/research/06-photo-vfx-3d.md`
