---
name: fsh-music-mood-bridge
description: Bridge between marketing-defined target audience and concrete music criteria. Demographic → music-mood mapping (YAML personas), editorial judgment (when to add music vs leave silence, when to drop it mid-piece), beat-sync editing patterns (allin1 + beat_this), LAION-CLAP retrieval over a local royalty-free library. Use when the strategy doc calls for music and the agent must decide WHAT KIND, WHEN, and WHY.
version: 1.0.0
---

# Music ↔ Marketing Bridge

The research surveyed every public OSS skill for marketing-to-music
mapping. **Nothing exists.** This file is the FotoStudioH-native skill
that bridges the marketing layer ("audience: Gen-Z TikTok fitness
creators") to concrete music criteria the
`agents/fsh-royalty-free-music/SKILL.md` aggregator can search against.

## Three editorial questions the skill answers

Before any music is added, the agent answers:
1. **Should music be added at all** for this beat / scene / project?
2. **What kind** — genre, BPM, key, energy, era, instrumentation?
3. **Why** — what semiotic + structural work is the music doing?

If question 1's answer is "no", stop. Don't add music. Silence is a
valid choice.

## When to ADD music (Q1)

Decision tree per beat / scene:

```
Is this a montage of multiple shots?              → YES, music almost always
Is this a vlog opener / first 30s?                → YES, vlogs need music in first beats
Is this a hook beat (1-3s) in short-form?         → YES, music drives retention
Is this a transition between scenes/sections?     → YES, music carries the bridge
Is this a corporate explainer or brand piece?     → USUALLY, low-energy music bed
Is this a music video?                            → ALL music, by definition

Is this a documentary interview, sit-down?        → MAYBE — only if dialogue rhythm needs support
Is this a vulnerable, emotional reveal?           → USUALLY NO — let silence work
Is the subject grieving / mourning / wounded?     → PRESUMPTIVELY NO (Murch silence rule)
Is the moment intentionally absurd or ironic?     → MAYBE — music adds the joke
Is this a confession / breaking news / death?     → NO — music here reads as exploitative
Is silence what the script demands?               → NO music, period
Is dialogue intelligibility the priority?         → NO music or very low-bed
```

Documentary doctrine (No Film School, Documentary.org): **"is music
necessary? will it enhance and/or support the intent of each
sequence?"** If the answer isn't clearly yes, the default is no music.

## When to DROP music mid-piece (Q2 mid-clip)

Drop-then-slam pattern (Scorsese, Murch on *Apocalypse Now*):
- A loud "moment" preceded by a music-off section reads as climactic
- A reveal during silence lands harder
- The "miraculous" pattern (Murch): music disappears and the audience
  doesn't notice the exit but feels its absence

Concrete drop triggers per cue:
- Just before a major payoff word in the narration
- At a deliberate visual reveal
- When a new speaker enters
- For 2-5 seconds before a smash-cut
- At a button-end (the cue's resolution point — see editorial-theory SKILL)

## Demographic → music criteria mapping (the YAML)

Persona-keyed YAML lives at
`agents/fsh-music-mood-bridge/personas.yaml`. Each entry produces a
search spec for `fsh-royalty-free-music`. Starter set:

```yaml
# Gen-Z creators
"Gen-Z TikTok fitness creators":
  genres: [hyperpop, trap, drill, jersey-club, dance-pop, brazilian-funk]
  bpm: [120, 160]
  era: [2022, 2026]
  energy: [0.75, 1.0]
  valence: [0.5, 1.0]
  vocal: optional
  duration_target_s: [15, 60]
  trend_source: tiktok_creative_center
  notes: Hook must land in 1-3s. Lyric-free preferred for safety.

"Gen-Z TikTok aesthetic / lifestyle":
  genres: [phonk, lo-fi, hyperpop, indie-pop, alt-rnb]
  bpm: [85, 130]
  era: [2020, 2026]
  energy: [0.55, 0.85]
  valence: [0.4, 0.9]
  duration_target_s: [15, 60]

# Millennial creators
"Millennial professional creators on YouTube":
  genres: [indie-folk, corporate-uplifting, ambient-electronic, chillhop, neo-soul]
  bpm: [95, 125]
  era: [2015, 2026]
  energy: [0.5, 0.8]
  valence: [0.55, 0.85]
  vocal: instrumental_preferred
  duration_target_s: [60, 300]

# B2B / corporate
"B2B SaaS execs on LinkedIn":
  genres: [corporate-uplifting, ambient-electronic, neo-classical, indie-folk]
  bpm: [90, 120]
  era: [2015, 2026]
  energy: [0.4, 0.7]
  valence: [0.6, 0.9]
  vocal: instrumental_only
  duration_target_s: [30, 180]
  notes: "Avoid: drops, vocals, anything 'club'. Default to gentle pulse-driven indie."

"B2B enterprise (Fortune 500 stakeholders)":
  genres: [neo-classical, ambient-electronic, contemporary-orchestral]
  bpm: [60, 100]
  era: [2010, 2026]
  energy: [0.3, 0.6]
  valence: [0.5, 0.85]
  vocal: instrumental_only
  duration_target_s: [60, 240]

# Cinematic / brand
"Cinematic brand pieces (luxury / lifestyle)":
  genres: [neo-classical, ambient-electronic, post-rock, contemporary-orchestral]
  bpm: [60, 100]
  era: [2010, 2026]
  energy: [0.35, 0.75]
  valence: [0.4, 0.85]
  vocal: instrumental_preferred
  duration_target_s: [60, 240]

# Family / kids
"Family / kids content (4-10 year olds)":
  genres: [acoustic-pop, light-orchestral, ukulele, children-friendly-indie]
  bpm: [100, 130]
  era: [2015, 2026]
  energy: [0.55, 0.85]
  valence: [0.7, 1.0]
  vocal: optional
  notes: NO minor keys with energy <0.5. Avoid sudden loudness changes.

# Wedding
"Wedding ceremony":
  genres: [neo-classical, acoustic-folk, instrumental-romantic, contemporary-orchestral]
  bpm: [55, 90]
  era: [2010, 2026]
  energy: [0.2, 0.5]
  valence: [0.6, 0.95]
  vocal: instrumental_only
  duration_target_s: [120, 480]
  notes: "Match key to processional/recessional cultural conventions."

"Wedding reception montage":
  genres: [dance-pop, indie-rock, latin-pop, motown-revival]
  bpm: [110, 145]
  era: [1980, 2026]
  energy: [0.65, 0.95]
  valence: [0.7, 1.0]
  duration_target_s: [60, 180]

# Documentary
"Documentary feature (intimate / character-driven)":
  genres: [neo-classical, ambient-electronic, post-rock, minimalist-piano]
  bpm: [50, 90]
  era: [2000, 2026]
  energy: [0.25, 0.65]
  valence: [0.3, 0.8]
  vocal: instrumental_only
  notes: "Be willing to leave NO music. Pearlman: 'the hold is where the work is.'"

"Documentary investigative (urgency)":
  genres: [ambient-tense, score-suspense, minimalist-percussion]
  bpm: [60, 110]
  era: [2000, 2026]
  energy: [0.4, 0.85]
  valence: [0.2, 0.6]
  vocal: instrumental_only
```

The YAML is a living table. Add personas as the agent encounters new
audience categories.

## Mapping persona → search query

```python
import yaml
from pathlib import Path
from fsh_royalty_free_music import find_music

personas = yaml.safe_load(
    Path('/agents/fsh-music-mood-bridge/personas.yaml').read_text()
)

def music_for_persona(persona_key: str, mood_hint: str, duration_s: int):
    spec = personas[persona_key]
    return find_music(
        mood=f"{mood_hint}, {', '.join(spec['genres'])}",  # text for CLAP
        bpm=tuple(spec['bpm']),
        duration_s=(duration_s, int(duration_s * 1.5)),
        license=['CC0', 'CC-BY', 'pixabay', 'mixkit', 'ncs-monetized'],
        era=tuple(spec['era']),
        energy=tuple(spec['energy']),
        valence=tuple(spec['valence']),
        genres=spec['genres'],
        has_vocals=(False if spec.get('vocal') == 'instrumental_only' else None),
        max_results=20,
    )
```

## Beat-sync editing — when music is locked

Once a track is picked, run `mir-aidj/all-in-one` on it to get
structured timing:

```bash
/opt/ml-venv/bin/python -c "
import allin1
r = allin1.analyze('edit/music_bed.mp3')
print('BPM:', r.bpm)
print('Beats:', r.beats[:8])
print('Downbeats:', r.downbeats[:8])
print('Segments:', [(s.label, s.start, s.end) for s in r.segments])
"
```

Use the output to:
- Snap visual cuts to beats (or to the syncope just before — see
  `agents/fsh-editorial-theory/SKILL.md` § Music-vs-narrative)
- Land scene transitions on downbeats
- Time payoff visuals to chorus boundaries
- Drop music during verse → return on chorus pattern

## Editorial veto over the marketing brief

When marketing says "use trending TikTok sound" BUT the content is:
- Grief / mourning / death
- A child subject in a vulnerable moment
- Asymmetric power dynamic (boss/employee, doctor/patient, etc.)
- Financial loss / hardship
- Medical diagnosis / disease
- Institutional dignity moment (funeral, swearing-in, memorial)

→ **Editor vetoes the brief.** Default to silence OR solo piano /
strings. Trending / energetic / ironic music is presumptively WRONG.

Anchor case: *Hearts and Minds* (1974) used patriotic music over
napalm footage as DELIBERATE irony — the choice was earned and
explicit. Accidental irony from a thoughtless trending pick reads as
contemptuous. Default to "absence" until you can argue for the
specific track.

When the editor vetoes, document in `/work/<id>/docs/strategy.md`:

```markdown
## Music veto applied — <timestamp>

Marketing brief specified: "<original direction>"
Veto reason: <which trigger fired>
Replaced with: <silence | solo piano | minimal ambient>
Hearts-and-Minds test: did NOT pass — the irony would read as
exploitative, not deliberate.
```

## Mastering the music bed (different from broadcast vocal chain)

For music-bed audio (not dialogue):
- Apply sidechain ducking under dialogue: 6-12 dB reduction below the
  dialogue band (60 Hz - 8 kHz)
- Reach for matchering against a curated reference matching the target
  delivery LUFS — but ONLY for streaming/web targets, NEVER for
  IMAX-bound mixes (matchering crushes dynamics)
- LSP multiband on the music bed → ZAM brickwall at -1 dBTP / -2 dBTP
- See `agents/fsh-broadcast-vocal-chain/SKILL.md` for the broader
  chain; this skill defers to that one for the actual mastering

## Skills to call (in order, when a project needs music)

1. Read the marketing brief / strategy doc
2. Identify the persona → look up in personas.yaml
3. `fsh-royalty-free-music.find_music(...)` → get top-20 candidates
4. Apply editorial-veto checks → trim candidates
5. For top 3-5 candidates: download preview, run `allin1.analyze()`
6. Present to user with: title, artist, source, license, BPM, segments,
   30s preview, agent's confidence rationale
7. User picks (or agent picks if `manifest.music.auto_pick = true`)
8. Lock the track into `manifest.music.track`
9. Spot-place cues per Musco's cue-arc doctrine (see
   `agents/fsh-editorial-theory/SKILL.md`)
10. Hand off to the mastering chain (`fsh-broadcast-vocal-chain/SKILL.md`)

## Cross-references

- Aggregator + license-handling: `agents/fsh-royalty-free-music/SKILL.md`
- Beat-sync mechanics (`allin1`, `beat_this`): `docs/research/07-music-workflow.md`
- Editorial theory (cut on beat vs syncope): `agents/fsh-editorial-theory/SKILL.md`
- Editorial-judgment prose sources (Murch, Pearlman, Musco):
  `docs/research/09-music-editorial-judgment.md`
- Audio AI for music search (CLAP, Essentia tagging): `docs/research/10-audio-ai-search-tagging.md`
- IMAX mastering caveats: `docs/research/08-cinema-imax-mastering.md`
