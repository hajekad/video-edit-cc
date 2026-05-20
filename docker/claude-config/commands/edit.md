---
description: Top-level entrypoint. Edit a project end-to-end from /assets input.
argument-hint: <project-name> [optional-prompt]
---

# /edit — full pipeline driver

Run the complete FotoStudioH pipeline on the project at `/assets/$1/`.

## What to do

1. **Verify input exists.** If `/assets/$1/` doesn't exist, ask the user
   to drop their files there and try again. Acceptable contents:
   - `/assets/$1/raw/` with one or more video files
   - `/assets/$1/raw.zip` (extract it into `raw/` first)
   - `/assets/$1/<single>.mp4` (move into `raw/<single>.mp4`)
   - `/assets/$1/prompt.txt` (optional edit brief)

2. **Scaffold workspace** at `/work/$1/`:
   ```bash
   mkdir -p /work/$1/{edit/{transcripts,clips_graded,animations,verify},docs/issues,.claude/state}
   ln -sfn /assets/$1/raw /work/$1/raw
   cd /work/$1 && git init -q && git config commit.gpgsign false
   ln -sfn /opt/claude-config/hooks /work/$1/.claude/hooks
   ln -sfn /opt/claude-config/settings.json /work/$1/.claude/settings.json
   ```

3. **Initialize `manifest.json`** at `/work/$1/manifest.json`:
   ```json
   {
     "id": "$1",
     "stage": "input-received",
     "created": "<RFC3339 UTC now>",
     "inputs": [],
     "strategy": { "approved": false },
     "overlays": [],
     "subtitles": { "style": "bold-overlay" },
     "output_spec": { "width": 1920, "height": 1080, "fps": 30, "codec": "h264_nvenc" },
     "delivery": { "mp4": true, "nle_xml": true }
   }
   ```

4. **Initialize `project.md`** with a "Session 1" header, the user prompt
   (if `$2` provided OR `prompt.txt` exists), and the current UTC time.

5. **Inventory.** ffprobe every file in `raw/`, push results into
   `manifest.inputs[]`. Flip `stage: inventoried`.

6. **Hand off to the continuous-worker loop.** Set `cd /work/$1` so
   `loop-not-done.sh` sees this as the active project. The Stop hook
   chain will direct each subsequent stage.

## When NOT to use `/edit`

- For an existing project where you already know the stage: just `cd /work/<id>` and let the loop drive.
- For an inventory-only pass: use `/inventory <project-name>` instead — it stops at `inventoried`.
- For URL inputs (YouTube): use `/edit-url <url> [project-name]` (separate command, not yet built).

## Output

Final deliverables land in `/assets/$1/output/`:
- `final.mp4` (always)
- `final.fcpxml` (if `manifest.delivery.nle_xml == true`)
- `final.xml` (FCP7/Premiere/Resolve format)

User sees them in the same dir they dropped inputs into.
