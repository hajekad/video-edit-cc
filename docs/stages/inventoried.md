# Stage: inventoried

Workspace exists. Now probe every source, transcribe, and pack a
phrase-level reading view.

## Entry condition

- `manifest.stage == input-received`
- `raw/` symlink resolves to non-empty `/assets/<id>/raw/`

## What to do

1. **ffprobe** every file in `raw/`:
   ```bash
   for f in raw/*; do /opt/claude-config/tools/ffprobe-json "$f"; done
   ```
   Push results into `manifest.inputs[]` with fields: `path`, `duration_s`, `width`, `height`, `fps`, `codec`, `audio_sample_rate`.

2. **Transcribe** every audio-bearing source via WhisperX on GPU:
   ```bash
   /opt/ml-venv/bin/whisperx \
       --model large-v3 \
       --language en \
       --diarize \
       --output_format json \
       --output_dir edit/transcripts/ \
       <source>
   ```
   One JSON per source under `edit/transcripts/`. Cache hit: if the
   JSON exists and the source mtime is older, skip (Hard Rule 9).

3. **Pack** transcripts into `edit/takes_packed.md` — phrase-level
   lines broken on silence ≥ 0.5s OR speaker change. Format:
   ```
   ## <source-id>  (duration: 43.0s, 8 phrases)
     [002.52-005.36] S0 First phrase here.
     [006.08-006.74] S0 Second phrase.
   ```
   Use the pack pattern from `agents/video-use/helpers/pack_transcripts.py`.

4. **One-pass skim** for slips, retakes, off-thesis material. Note them
   in `docs/pre-scan.md` (one bullet per slip; feed into strategy
   brief).

5. **Update manifest**: `stage = inventoried`. Commit.

## Advance to: strategy-confirmed

Next stage requires user approval. Do NOT auto-advance.

## Pitfalls

- **GPU OOM on large-v3.** If you hit it, drop to `medium` and
  document it as a `Capability` issue (not a Bug — the agent's
  hardware limits the model size).
- **WhisperX phrase mode.** Never use it. Word-level only (Hard Rule 8).
- **Non-English content.** Pass `--language <iso>` explicitly; auto-detect
  is unreliable on first few seconds.
- **Re-transcribing.** Cache check by source mtime + size. Re-transcribe
  ONLY if either changed.
