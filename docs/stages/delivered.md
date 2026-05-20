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
