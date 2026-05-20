# Research: music editorial judgment — when/what/why

Background research output from a parallel agent. Six questions:
WHEN to add music vs leave silence, WHEN to drop the music mid-piece,
WHAT KIND fits WHICH moment, WHY it works (semiotics), music-vs-narrative
interaction patterns, WHEN editorial overrides the marketing brief.

## Key finding

**No GitHub repo with 30+ stars exists for music editorial judgment.**
The niche is essentially unencoded in OSS. The LLM-internalizable material
lives in prose (books, blog posts, interviews) — not skill repos. **Q3
(mood-to-music table) and Q6 (editor-overrides-marketing) are the
hand-author gaps.**

## 12 must-have references (ranked by density of LLM-internalizable rules)

1. **Walter Murch — *In the Blink of an Eye*** (archive.org/details/inblinkofeye00murc) + Transom 2005 interview (transom.org/2005/walter-murch). Foundation. Rule of Six (Emotion 51% → Story → Rhythm → Eye-trace → 2D → 3D), the silence-as-metaphor passage, the helicopter-music-removal anecdote, the 5-layer simultaneity rule.

2. **Karen Pearlman — *Cutting Rhythms*** (multiple PDFs / Routledge / Perlego / archive.org). Editorial-intuition framework: expertise + implicit learning + judgment + sensitivity + creativity + rumination. Translatable to LLM chain-of-thought scaffolding.

3. **Michael Musco — *Structural Language Music Supervisors Expect*** (michaelmusco.com/2026/02/structural-language-music-supervisors-expect.html). Most directly recitable editorial-rule text. Button endings, cue arc (Intro → Development → Peak → Resolution/button), standard cue durations, strong edit points (bar lines, transients, phrase ends, dropouts, sustained chords) vs weak edit points (melodies overlapping boundaries, reverb smear). **Lift wholesale.**

4. **Documentary.org — *Minding Your Beats and Cues***. Documentary-specific necessity tests + spacing heuristics. Recitable test: *"Is music necessary? Will it enhance and/or support the intent of each sequence?"*

5. **Lehigh DH essay — *Noises Off: Ironic Use of Music***. Best teaching example for Q4 semiotics + irony rules. *Hearts and Minds* (patriotic music over napalm) as textbook ironic-music example.

6. **Annabel Cohen — Congruence-Association Model** (CAM-WN). Cognitive-psych grounding. Mood-congruent pairs encode jointly; incongruent pairs encode independently → memorable as irony.

7. **No Film School — *Music vs. Silence: 5 Simple Rules*** + *Why Filmmakers Use Silence*. Short, blunt, prescriptive. Q1 anchor.

8. **Thomas Golubic interviews** (Red Bull Music Academy + Pop Disciple). Closest thing to "music supervisor moral compass." *"less, less, use music really sparingly, very intentionally."* On Breaking Bad: producers told them their wall-to-wall score was *"spackle and cover things."* Q6 anchor.

9. **Daniel Pemberton — Spitfire Audio interview**. Recitable: *"if you write music that gets in the way of key information and distracts from key moments — even if it's a great piece of music — then it's not good film music."*

10. **Steven Saltzman — *Music Editing for Film and Television*** (archive.org/details/musiceditingforf0000salt). The actual craft textbook. Case studies for few-shot examples.

11. **Ramsay Adams / Hnatiuk / Weiss — *Music Supervision: Complete Guide***. Supervision-side companion to Saltzman.

12. **PremiumBeat / Soundstripe editorial blogs**. Secondary — useful for genre-by-vertical heuristics (corporate explainer = calm classical; unboxing = upbeat electronica).

## The six editorial questions

### Q1 — WHEN to add music vs leave silence
Best sources: No Film School *Music vs. Silence: 5 Simple Rules* + *Why Filmmakers Use Silence*; Documentary.org necessity test; Murch's silence-as-metaphor passage (*"if you can get the film to a place with no sound where there should be sound, the audience will crowd that silence with sounds and feelings of their own making"*).

Tension worth encoding: documentary doctrine says silence is the goal at emotional peaks; short-form vlog retention research says silence in the first 30s kills retention. Both are true; the rule is content-type-dependent.

### Q2 — WHEN to drop music mid-piece
**Strongest LLM source**: Murch (Transom) — Apocalypse Now helicopter example, *"the miraculous thing is that you do not hear it go away — you believe that it is still playing."*

Musco's structural sync rules: button endings, music arc shape, standard cue durations (0:30 / 1:00 / 1:30 / 2:00 / 2:30-3:00), strong vs weak edit points. Drop-then-slam pattern (Scorsese): "soundtrack disappearing... forcing focus on the moment — before punching it back in abruptly."

### Q3 — WHAT KIND fits WHICH moment
**Biggest gap. No clean OSS lookup table.** Closest:
- SongSmith Suno cheat-sheet (partial mapping: minor + 70-85 BPM = grief/heartbreak; major + 120+ BPM = anthemic; minor + 125+ BPM = aggression)
- Tempo classes (largo 40-60 → prestissimo 200-208) via blog.flat.io
- Hooktheory *Cinematic Chord Progressions*
- Daws *Effects of Tempo, Texture, and Instrument on Felt Emotions* (academic, has instrument-emotion data: oboe/trumpet/violin = high-arousal positive; bassoon/clarinet/flute/horn = low-arousal)

**Hand-author**: a CSV/YAML lookup `mood → BPM range, key, instrumentation hint, "do" examples, "do not" examples` sourced from Daws + Hooktheory + Soundstripe + royalty-free library tag pages. Living table.

### Q4 — WHY music works (semiotics)
**Academic foundation**: Cohen's Congruence-Association Model. Mood-congruent pairs encode jointly; incongruent pairs (irony) encode independently and become memorable.

**Irony specifically**: Lehigh DH essay — Hearts and Minds positive example, Mahler-in-de-Antonio negative ("not culturally familiar enough to register as ironic"). Chattah dissertation (FSU, free PDF) on equipollent oppositions.

**Recitable rule (Pemberton)**: *"if it gets in the way of key information... even if it's a great piece of music — then it's not good film music."*

### Q5 — Music-vs-narrative interaction
**Musco again**. Murch's 5-layer simultaneity / left-brain vs right-brain encoding spectrum. April Tucker dialogue editing series on ducking (music ducks under dialogue ~6-12 dB; sound design fills the gap; music returns at the breath).

**Beat-sync doctrine (FilmDaft / Toolfarm)**: *"editing to the beat isn't just about hitting every downbeat — try mixing it up... A hard cut on the 1/16-note lift just before the first downbeat of the next bar will be more interesting than if you just cut on the downbeat itself."* Counters the naive "all cuts on the 1" instinct.

**Spotting doctrine** (Fenoughty + Fiveable): SMPTE-precision in/out points, button-end alignment, editor-composer-supervisor watch-and-mark workflow.

### Q6 — When editor overrides the marketing brief
**Largest gap. Essentially un-encoded anywhere.** No SKILL.md, no playbook, no canonical blog says "veto the trending TikTok sound when the subject is grieving."

Closest analogues:
- Documentary.org *Keeping Your Films Soundtrack on Track* — music supervisor as expert at *"riding the narrative... focus the attention of the viewer on the subject"*. Implicit warning against wall-to-wall coverage.
- Golubic interviews — "less, less, use music really sparingly, very intentionally." Frames invisibility as a skill.
- Pemberton's "music in the way of key information" — closest one-liner to "veto" doctrine.
- Center for Media Engagement *The Ethics of TikTok Trends* — addresses ethics of trending audio over sensitive content broadly, not from editor-craft angle.

**Hand-author**: SKILL.md section *Editorial veto* listing concrete trigger cases (grief, trauma, vulnerable child subject, dignified institutional moment, deceased subject, asymmetric power dynamics, financial loss, medical diagnosis) with the rule: *"trending / energetic / ironic music is presumptively wrong; default to absence-of-music or solo piano/strings until proven otherwise."* Anchor with the Hearts-and-Minds example (irony is *deliberate*, never accidental).

## GitHub honest accounting

No repo with 30+ stars exists for music editorial judgment. Examined: SB-Jeff/documentary-junior-editor (2★), kneha07/SoundAgent-Agentic-AI-Music-Recommender- (0★), bohem007/AI-film-music-supervisor (0★), wtv1gnf3hbk/needle-drop-knowledge (0★), Sam-StoryEngine/davinci-resolve-ai-skill, mwarf/plotline, adsventurestudio-sudo/documentary-editing-workflow. Music appears as a *parameter* ("music mood: ___") in many video-skill repos (frvnkfrmchicago/skills-library-v2, ponyflash/ponyflash-skill, Felix201209/AutoDirector-Studio) but no repo contains prose rules about the judgment behind those fields.

## Conclusion

Don't clone anything. Q3 (mood-to-music table) and Q6 (editorial veto) are the hand-author gaps. Everything else is reference-only synthesis from the 12 sources above.
