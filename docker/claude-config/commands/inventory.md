---
description: Inventory inputs and transcribe — stop before strategy.
argument-hint: <project-name>
---

# /inventory — probe + transcribe, no cuts

Same as `/edit $1` up through stage `inventoried`, then stop. Useful when
the user wants to review the packed transcript before committing to a
strategy.

## What to do

1. Scaffold workspace at `/work/$1/` (same as `/edit`, steps 2–4).

2. **ffprobe** every input file:
   ```bash
   for f in /work/$1/raw/*; do
       ffprobe -v error -print_format json -show_format -show_streams "$f"
   done
   ```
   Push duration, fps, resolution, codec, audio_sample_rate into
   `manifest.inputs[]`.

3. **Transcribe** every input via WhisperX on GPU:
   ```bash
   /opt/ml-venv/bin/whisperx \
       --model large-v3 \
       --diarize \
       --output_format json \
       --output_dir /work/$1/edit/transcripts/ \
       "/work/$1/raw/<file>"
   ```
   One JSON per source. Word-level timestamps with `words[].speaker`.

4. **Pack** transcripts into `/work/$1/edit/takes_packed.md` —
   phrase-level lines, break on silence ≥ 0.5s OR speaker change.
   Format:
   ```
   ## <source-id>  (duration: 43.0s, 8 phrases)
     [002.52-005.36] S0 Ninety percent of what a web agent does is completely wasted.
     [006.08-006.74] S0 We fixed this.
   ```

5. Update `manifest.stage = inventoried`. Commit.

6. **Stop and report.** Tell the user:
   - How many sources, total runtime
   - Any obvious slips, retakes, off-thesis material from a one-pass
     skim of `takes_packed.md`
   - Suggest they read it and run `/plan $1` when ready

## Why this exists

Inventory + transcription are expensive (WhisperX large-v3 on a
12GB GPU is several minutes per source). The user may want to read the
packed transcript and adjust intent before committing to a strategy.
