# Stage: delivered

Render the final at delivery spec, export NLE XML (if requested), copy
everything into `/assets/<id>/output/`. This is the terminal stage —
project goes idle after.

## Entry condition

- `manifest.stage == self-eval-passed`
- `/work/<id>/.claude/state/self-eval.verdict` first line == `PASS`

## What to do

### 1. Render final at delivery spec

```bash
python /agents/video-use/helpers/render.py \
    /work/<id>/edit/edl.json \
    --width <manifest.output_spec.width> \
    --height <manifest.output_spec.height> \
    --fps <manifest.output_spec.fps> \
    --codec <manifest.output_spec.codec> \
    --subtitles /work/<id>/edit/master.srt \
    -o /work/<id>/edit/final.mp4
```

Defaults: 1920x1080, 30fps, h264_nvenc, CRF/CQ 18.

This is the expensive render. Don't skip the preview gate — once
final.mp4 is wrong, you re-render the full thing.

### 2. Optional: NLE XML export

If `manifest.delivery.nle_xml == true`:

```bash
ruby -I/agents/buttercut/lib /agents/buttercut/scripts/export.rb \
    --edl /work/<id>/edit/edl.json \
    --output /work/<id>/edit/final.fcpxml \
    --format fcpx
```

Repeat with `--format fcp7` for Premiere/Resolve XML
(`/work/<id>/edit/final.xml`).

Validation: open the XML in `xmllint --noout` to catch structural
errors before delivery.

### 3. Copy outputs into /assets/<id>/output/

```bash
mkdir -p /assets/<id>/output/
cp /work/<id>/edit/final.mp4 /assets/<id>/output/final.mp4
[ -f /work/<id>/edit/final.fcpxml ] && cp /work/<id>/edit/final.fcpxml /assets/<id>/output/
[ -f /work/<id>/edit/final.xml ] && cp /work/<id>/edit/final.xml /assets/<id>/output/
```

The user finds deliverables in the SAME directory they dropped inputs.

### 4. Optional: deliverables (thumbnail, description, transcription copy)

If `manifest.delivery.deliverables` is set, generate per
`agents/Claude-Video-Editor-Plugin/skills/generate-deliverables/`:
- Thumbnail (poster-frame at strategic moment OR manual frame)
- LLM-generated description (YouTube / LinkedIn / plain styles)
- Transcription copy (clean SRT + TXT)

Place in `/assets/<id>/output/` alongside the video.

### 4b. Per-deliverable folders + delivery zip (REQUIRED)

In addition to the loose files in `/assets/<id>/output/`, ALWAYS write
a zip archive at `/assets/<id>/output/<slug>_delivery.zip` with one
folder per delivered video. This is non-negotiable and applies to both
single-cut (n=1) and multi-cut (n>1) projects — the convention is
identical.

Structure:

```
<slug>_delivery.zip
  cut1/                            (or "final/" when n=1)
    cut1_INTERNAL_REVIEW.mp4        ← preview variant (music baked, watermarked)
    cut1_CLEAN_FOR_UI_MUSIC.mp4     ← shippable variant (no music, supers on)
    cut1_NO_SUBS.mp4                ← REQUIRED no-subtitles variant (no music, supers off)
    publish_instructions.txt        ← how to publish + music source
  cut2/
    ...
```

**The three variants are non-negotiable on every cut, every project:**

1. **`<cut>_INTERNAL_REVIEW.mp4`** — picture + supers + music baked at target
   LUFS (watermarked from the AJ preview voice or "PITCH PREVIEW" burn on
   trend tracks). Sign-off artifact only — never published.
2. **`<cut>_CLEAN_FOR_UI_MUSIC.mp4`** — picture + supers + ambient audio,
   no music stem. Brand team uploads this muted and adds licensed music in
   the platform UI per `docs/music_cues.md`.
3. **`<cut>_NO_SUBS.mp4`** — picture + ambient audio, **no music AND no
   on-screen supers**. Required for: re-subtitling into another language,
   repurposing the cut for surfaces that generate their own captions
   (LinkedIn, YouTube auto-captions), B-roll reuse, or sound-off thumbnails
   where supers compete with the platform's overlay UI. Same source picture
   as CLEAN, just with the drawtext super chain skipped at fragment-render time.

When a cut ships multiple music options (e.g. Cut 6 of the PyrolyzaKveten
project shipped three trend tracks A/B/C), name the music-bearing variants
`<cut>_<id>_INTERNAL_REVIEW.mp4` / `<cut>_<id>_CLEAN_FOR_UI_MUSIC.mp4` and
keep a single shared `<cut>_NO_SUBS.mp4` (music-free regardless of option).

When the project has only `platform_final` (no two-variant split — e.g.
YouTube long-form, broadcast), the per-cut folder still has all three
variants: the single baked mp4, a music-free clean version, and the
no-supers version. The instructions name the baked music's license proof
file instead of an IG-UI add workflow.

Each `publish_instructions.txt` MUST include, in this order:

1. **Header** — cut number (or "final"), cut title (CZ + EN if bilingual),
   audience segment, project name, format spec (resolution / fps / platform).
2. **Files in this folder** — one line per file naming preview vs shippable
   vs no-subs, including explicit "DO NOT publish the preview" AND a one-line
   explanation of when the NO_SUBS variant is useful (re-subtitling,
   alternate language, surfaces that add their own captions).
3. **How to publish** — numbered step-by-step (open app → upload → mute
   original audio → add music → caption → safe-zone check → publish).
   Phrased for someone airdropping the folder to a phone.
4. **Music** — track title + artist + source URL/library + proxy file
   used in INTERNAL_REVIEW + license posture (purchase path, IG UI add,
   royalty-free baked, etc.) + how to add it on the platform + the
   sync-hit timecodes from `docs/music_cues.md` for that cut.
5. **Caption** — CZ + EN copy ready to paste, with hashtags. CZ-only
   when the cut's subtitle plan is CZ-only.
6. **Brand-compliance checklist** — pre-publish gates as `[ ]` boxes.
7. **Handoff notes** — pointers back to `docs/strategy.md § Cut N`,
   `edit/music/_license_notes.md`, `docs/brand_pollution_audit.md` (if
   present), and any logo-dropin status.

**Why this exists:** the brand/marketing team commonly downloads the
delivery onto a phone before publishing. Loose files in the root output
folder are awkward to navigate on mobile and per-video instructions are
easy to lose in a sea of docs. A self-contained per-video folder — with
the file + instructions adjacent — removes that friction. They airdrop
one folder, open the .txt, follow the steps, publish. Reference case:
PyrolyzaKveten Q2-2026, where the creator explicitly asked for this
convention as the always-default packaging.

**Implementation:** write a `edit/build_delivery_zip.py` per project.
PyrolyzaKveten Q2-2026 has the canonical reference implementation at
`/work/q2-2026-pyrolyzakveten/edit/build_delivery_zip.py` — copy and
adapt the per-cut music dictionary + caption blocks. It reads the cut
JSONs + `docs/music_cues.md` + manifest, stages folders under
`edit/_zip_staging/`, then emits the zip into the output dir.

**Do NOT skip this even when n=1.** Single-final projects get a `final/`
folder inside the zip, same shape. Consistency beats minimalism — every
project ships the same package shape, every brand team learns one workflow.

### 4c. Logo dropin — auto-bug every cut once the file lands (REQUIRED)

When the brand logo dropin is present at
`/assets/<id>/branding/<brand>_logo_<variant>.png` (variant ∈
{color, white, mono}), **every cut variant** in the delivery — INTERNAL_REVIEW,
CLEAN_FOR_UI_MUSIC, NO_SUBS, and every music sub-variant when a cut ships
multiple music options — MUST carry the logo overlaid as a corner bug.

Defaults (overridable in `manifest.brand.bug`):
- Position: top-left, 6% padding from edges
- Size: 14% of frame width
- Aspect: preserve, no skew, no recolor
- Eagle + wordmark together — never separate (per ORLEN-style brand
  source notes; same rule for any brand lockup)

Implementation: bake the overlay during the base-render step. PyrolyzaKveten
Q2-2026 has the canonical implementation at
`/work/q2-2026-pyrolyzakveten/edit/render_cut.py` (`add_logo_bug` helper +
its invocation from `render_cut`).

Close cards: when `manifest.brand.logo_path` is set, the close card
replaces the typographic ORLEN wordmark with the actual lockup PNG
overlaid at center (≈36% width). The brand source-notes typically forbid
typographic-only wordmarks because they separate the wordmark from the
brand symbol.

**Why this exists:** Reference case — smoke #3 PyrolyzaKveten Round 2.
The agent removed a clashing typographic ORLEN overlay top-left after
user feedback, but did NOT replace it with the dropped logo, so every
cut shipped without the brand bug. Brand teams expect the logo on every
frame of every cut, not "when convenient."

**If no dropin is present:** ship the cuts without a corner bug (do NOT
fall back to a typographic wordmark — clashes with in-frame coverall
patches / brand-visible footage). Flag in the delivery README that the
logo dropin is pending and provide the re-render command for when it
lands.

### 5. Update manifest + close

```bash
jq '.stage = "delivered" | .delivered_at = "<RFC 3339 UTC now>"' \
    /work/<id>/manifest.json > /tmp/m && mv /tmp/m /work/<id>/manifest.json
```

Append a session-close section to `/work/<id>/project.md`:

```markdown
## Session N — Delivered <date>

**Final deliverables:**
- /assets/<id>/output/final.mp4 (<size>, <duration>)
- /assets/<id>/output/final.fcpxml
- /assets/<id>/output/final.xml

**Hard rules verified:** 1-12 (cite specific evidence)

**Self-eval verdict:** PASS — <reason from verdict marker>

**Open issues at delivery:** <count> (link to ids if any P2 deferred)
```

Auto-commit captures all of this.

### 6. Tell the user

In ONE short message:
- Where the deliverables are
- Total runtime
- Any P2 issues you deferred
- Suggest the next prompt (e.g., "drop another project into /assets/")

Then the loop sees `stage = delivered`, the next active-project picker
returns nothing, and the agent goes idle.

## Pitfalls

- **Skipping preview/self-eval and rendering final directly.** You'll
  catch issues 2-5x slower because final renders are slow.
- **`/assets/<id>/output/` not created.** Hard Rule 12 — outputs MUST
  land where the user can find them. `pipeline-gates.sh delivered`
  checks this.
- **Skipping the delivery zip (§ 4b).** Loose files alone don't ship.
  Every project gets the `<slug>_delivery.zip` with per-video folders
  + publish_instructions.txt — even n=1. Brand/marketing teams airdrop
  the folder to a phone and expect instructions adjacent to the file.
- **Shipping only INTERNAL_REVIEW + CLEAN_FOR_UI_MUSIC without NO_SUBS.**
  Three variants per cut, always. The NO_SUBS version is the difference
  between a cut that can be repurposed (re-subbed for another language,
  cross-posted to LinkedIn with platform-generated captions, used as
  B-roll, etc.) and one that's locked to a single language + platform.
  Same source picture as CLEAN — just render fragments with the super
  drawtext chain skipped. Cheap to add, expensive to retrofit later.
- **publish_instructions.txt that names the music vibe but not its
  source.** "Cinematic corporate" isn't a license path. Name the
  AudioJungle ID / YouTube URL / IG library sound name + the exact
  purchase or platform-add workflow. If the marketing team can't
  recreate the music from the txt file alone, the txt file failed.
- **Forgetting to commit.** auto-commit fires on Stop, but if you stop
  mid-step the .verdict files and manifest update might miss the
  commit window. Manually verify after.
- **Final.mp4 < 1MB.** Sign of truncation. pipeline-gates flags this.
- **NLE XML opened in wrong app.** FCP X reads `.fcpxml`; Premiere
  reads the `.xml` variant. Don't cross-deliver.
- **Bragging about quality without evidence.** Final report cites the
  verdict marker + gate-pass output. No marketing language.

## No further stage

`delivered` is terminal. The loop hook sees this and returns idle.
If the user wants edits to a delivered project, they reset the stage
manually OR file new issues under `/work/<id>/docs/issues/`. The
ladder re-walks from wherever they reset to.
