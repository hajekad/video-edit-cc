---
name: fsh-editorial-theory
description: Editorial craft theory for video cuts. Murch's Rule of Six (Emotion → Story → Rhythm → Eye-trace → 2D → 3D), Pudovkin's five montage modes, cut-type catalog (J-cut, L-cut, match cut, jump cut, smash cut, action cut), pacing-by-content-type matrix. Use when deciding WHERE to cut, WHY a cut feels right or wrong, or HOW to sequence beats. Read this before building the EDL in the edl-built stage.
version: 1.0.0
---

# Editorial Theory — Cut Craft

The research surveyed every public OSS skill repo for editorial theory.
**Nothing exists at this depth.** This file is the FotoStudioH-native
distillation of editing-craft prose from Walter Murch's *In the Blink
of an Eye*, Karen Pearlman's *Cutting Rhythms*, Steven Saltzman's *Music
Editing for Film and Television*, and No Film School practitioner blogs.

## Murch's Rule of Six (the only ranked rubric in editing)

When evaluating a cut, score these six in order. Earlier criteria
dominate later ones — a cut that nails emotion is worth a slight breach
of eye-trace, never the reverse.

| Rank | Criterion | What it means | Weight |
|---:|---|---|---:|
| 1 | **Emotion** | The cut respects the emotional truth of the moment. Are we letting the viewer *feel* what's happening? | 51% |
| 2 | **Story** | The cut advances narrative — answers a question or raises a new one. | 23% |
| 3 | **Rhythm** | The cut lands on a beat the body feels right (breath, beat, gesture). | 10% |
| 4 | **Eye-trace** | The viewer's gaze moves smoothly across the cut. Don't make the eye search. | 7% |
| 5 | **2D plane of screen** | Stage line / 180-degree rule. Screen direction holds. | 5% |
| 6 | **3D space of action** | Geographic continuity. Where things are relative to each other. | 4% |

Murch's litmus: "if I can get the top three, I can usually live with
violating one of the bottom three."

## Pudovkin's five montage modes

When sequencing beats, choose deliberately. The mode answers "what
relationship am I asserting between these two shots?"

1. **Contrast** — A vs B (rich/poor, peace/war, calm/chaos). Strongest emotional payload.
2. **Parallelism** — A and B happening simultaneously, related thematically. Used in cross-cut scenes.
3. **Symbolism** — A literal + B metaphorical. The viewer infers the meaning. (Eisenstein's "kino-fist.")
4. **Simultaneity** — A and B happening at the same TIME, the viewer holds both. (More mechanical than parallelism.)
5. **Leitmotif** — A recurring image/sound/idea that returns at moments of structural significance.

When the strategy doc says "documentary-style" without specifying mode,
default to contrast for emotional beats, parallelism for procedural
beats, leitmotif sparingly at key returns.

## Cut-type catalog

Each type has a specific use. Don't reach for a smash cut when an action
cut would do.

### Action cut (continuity cut)
Cut mid-action: subject lifts arm → next shot subject's arm already
raised. Hides the cut by exploiting motion. **Default for invisible
editing.** Use whenever the cut should NOT call attention to itself.

### J-cut
Audio of shot B starts BEFORE picture of shot B (audio leads picture).
Pulls the viewer into the next scene. Common in interviews: hear them
speak, then see them. Reveals attention.

### L-cut
Audio of shot A continues AFTER picture cuts to shot B (audio lags
picture). The reaction shot still hears the speaker. Common in
conversation.

### Match cut
Visual or sonic element bridges two shots (shape, color, motion, line).
"Bone-spinning-into-spacecraft" *2001*. **Use sparingly — too obvious
becomes corny.** Best when the visual rhyme adds meaning, not just
flair.

### Jump cut
Same axis, time skip. Once a violation (Godard's *Breathless* 1960),
now a vlog convention (every YouTube vlog uses them to compress
talking-head speech). **Modern usage**: tighten dead air and "ums" in
spoken-word content; do NOT use in narrative/cinematic work where they
read as amateur. Pair with `auto-cut-silences` skill for mass jump-cut
through silence.

### Smash cut
Loud or visually arresting cut from a quiet/static A to an explosive B.
Maximum disruption. **Use once or twice per film, at peak moments.** If
you use it three times it stops working.

### Dissolve / fade
Time passing, dream/memory, soft transition. **Default off in modern
short-form.** Use only when the script demands "X minutes later" or a
deliberate soft segue.

### Cutaway
Brief insert (B-roll, object detail, listener reaction) covering an
edit in A. **Functional**: bridge a content edit. Don't pad with random
cutaways — every cutaway must answer "why this image now?"

## Pacing-by-content-type matrix

Pacing isn't taste — it's mapped to content. Default cut-per-minute
ranges:

| Content type | Cuts/min | Avg shot length | Notes |
|---|---:|---|---|
| Documentary interview (sit-down) | 2–6 | 10–30s | Long shots; let speakers breathe. Cut on emotional reveals or topic shifts. |
| Documentary B-roll over VO | 8–15 | 4–8s | Slightly faster than the words; let the eye refresh. |
| Wedding ceremony (real-time) | 1–4 | 15–60s | Long, reverent. Don't intrude. |
| Wedding reception montage | 12–25 | 2–5s | High energy, music-driven, beat-synced. |
| Tutorial / screencast | 6–12 | 5–10s | Cut between speaker and screen; remove "uh"s. |
| Corporate explainer | 10–18 | 3–6s | Crisp, brand-paced, never lingering. |
| Music video (slow-tempo) | 15–30 | 2–4s | Beat-anchored. |
| Music video (uptempo / EDM) | 30–60+ | <2s | Hyper-cut, drop-driven. |
| TikTok / Reels (talking head) | 25–45 | 1–2s | Compressed for attention; modern vlog convention. |
| Sports highlights | 30–50 | 1–2s | Plays as a series; cut on completion of action. |
| Cinematic feature (drama) | 4–10 | 6–15s | Patience; let shots breathe; cut on emotional shift. |
| Trailer | 60–120 | 0.5–1s | Frenetic; one image per beat. |

When the strategy doc specifies "fast / conversational / cinematic",
map to: fast = top quartile of the range, conversational = middle,
cinematic = bottom quartile.

## When to NOT cut (silence-of-cuts)

A held shot is a deliberate choice. Reach for it when:

- The performance is delivering — cutting would interrupt
- The subject is grieving / vulnerable — cuts feel exploitative
- The viewer needs to absorb a reveal (post-payoff hold ≥ 1s)
- The composition is doing visual work the next shot would break
- Music is doing the work; cutting fights the rhythm

Default minimum hold: 1.5s for documentary, 3s for cinematic, 0.5s for
short-form. **Pearlman**: "the edit is not where the work is. The hold
is where the work is."

## The pre-cut checklist (every range in the EDL)

Before adding a range to `edl.json`, the editor sub-agent should
answer:

1. **What emotion does this beat carry?** (Murch #1)
2. **What question does it answer or raise?** (Murch #2)
3. **What is the rhythmic context — is it a downbeat, an offbeat, a breath?** (Murch #3)
4. **Where is the viewer's eye coming from, where is it going?** (Murch #4)
5. **Does this respect screen direction from the previous cut?** (Murch #5)
6. **Does this hold the geography we just established?** (Murch #6)

If a cut fails 1-3, do not include it. If it fails 4-6, include it
only if 1-3 are strong.

## Reference reading

These prose sources are the spine of editorial theory. The agent should
read the relevant chapters when working on cinematic or documentary
projects (skip for short-form vlog where conventions are different).

- **Walter Murch — *In the Blink of an Eye*** (archive.org/details/inblinkofeye00murc)
- **Karen Pearlman — *Cutting Rhythms*** (Routledge)
- **Steven Saltzman — *Music Editing for Film and Television*** (archive.org/details/musiceditingforf0000salt)
- **Walter Murch — Transom 2005 interview** (transom.org/2005/walter-murch) — the silence-as-metaphor passage
- **No Film School** — *Music vs. Silence: 5 Simple Rules* and *Why Filmmakers Use Silence*
- **Documentary.org** — *Minding Your Beats and Cues*

The 12 Hard Rules in `agents/CLAUDE.md` are non-negotiable mechanics.
This file is the *taste* layer that sits on top — it tells the agent
WHICH cut is right, after the mechanics confirm the cut is *possible*.

## Cross-references

- Hard Rules 1-12: `agents/CLAUDE.md`
- Pipeline stages: `docs/stages/edl-built.md` (where the EDL is built)
- Music interaction: `agents/fsh-music-mood-bridge/SKILL.md`
- Editorial veto over marketing brief: `docs/research/09-music-editorial-judgment.md` Q6
