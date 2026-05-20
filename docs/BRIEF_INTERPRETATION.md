# Brief Interpretation Doctrine

The agent's most-failed mode is **executing the literal request instead
of the underlying job**. A real user — a director, a marketing lead, a
small-business owner — does not write a deliverable spec. They write
intent in two sentences and expect the agent to infer the rest.

This doc is the agent's job-to-be-done expansion layer. Run it during
the `inventoried` stage, **before** writing `docs/strategy.md`. The
expansion lands in `manifest.brief_intent` so the user can audit it on
return and roll back if the inference was wrong.

> Reference case: smoke test #1 (PyrolyzaKveten). The brief was
> "Marketing team needs material, … top spec quality." Without this
> doctrine the agent shipped a generic edit. The user had to reprompt
> three times to extract: add music, format for Reels, research the
> target audience, pull the official logo. Every one of those is
> derivable from "marketing team" + vertical footage + identified
> petrochem subject. This doctrine makes that derivation automatic.

## The three-pass read

For every project, in this order:

1. **Surface read** — what does the brief literally say?
2. **Signal read** — what do the footage, subject, language, branding,
   and orientation imply about the real job?
3. **Audience read** — who is the eventual viewer of this artifact, and
   what does that imply about platform / length / music / caption style
   / pace?

Write each pass into `manifest.brief_intent` as you go. The agent must
not advance to `strategy-confirmed` until the three reads are recorded.

## Signal → inference table

The agent treats these as **defaults**, not certainties. When a signal
fires, the agent picks the inference and records it (with the signal
that fired) into `manifest.brief_intent`. The user audits on return.

### Footage signals

| Signal | Inference |
|---|---|
| All sources shot vertical (or composed-vertical without rotation flag) | Primary deliverable is a vertical short-form social cut (Reels / TikTok / Shorts) |
| Mix of vertical + landscape | Two-orientation deliverables; vertical primary if subject is a person / product close-up |
| 4K @ 50/60fps with shallow DOF | "Brand cinematic" register, not vlog. Cinematic grade, slower pace, music bed expected |
| 1080p phone footage, handheld | Documentary / vlog register. Tighter cuts, natural sound forward |
| Lavalier-clean audio | Talking-head or interview. Subtitles required, music bed at -18dB if present |
| Wind-noise or industrial ambient | B-roll-driven; lean on captions to carry meaning, music bed for cohesion |
| Multiple takes of the same line | Selects pass needed; pick the best read (look + diction + energy) |
| Drone establishing shots | "Place / scale" register. Wide-open music, no kinetic typography |

### Subject + brand signals

| Signal | Inference |
|---|---|
| Visible corporate logo, branded PPE, name patches | Identify the brand. Fetch official press kit. Use brand colors + voice |
| Industrial / refinery / lab / factory setting | B2B audience. Persona = "industrial / heavy industry" |
| Customer-facing retail / hospitality / event | B2C audience. Persona matches the brand's customer demographic |
| Wedding, family, kids | Personal audience. No corporate signaling; warm grade; intimate music |
| Founder / CEO / engineer talking head | "Voice of expert" register. Lower-third with name + role |
| Multiple speakers in conversation | Interview / panel. Diarize, label, hold on speaker for ≥1.5s per turn |
| Spoken language other than English | Burn subtitles in source language by default; offer English burn as a variant |

### Brief-keyword signals

| Brief contains | Inference |
|---|---|
| "marketing team", "marketing material" | Two-variant delivery (internal_review + platform_clean), brand-compliant, audience-targeted, music cues sheet |
| "social", "Reels", "TikTok", "shorts", "feed" | Vertical short-form. Internal review + clean variant. Music workflow per platform |
| "client", "client-ready", "client review" | Internal review variant ALWAYS. Brand assets fetched. Audit-trail commit log |
| "investor", "pitch", "deck" | Tight (≤90s), data-confident, restrained grade, lower-third metrics |
| "documentary", "story", "feature" | Long-form (≥3min), Murch silence doctrine, music sparingly |
| "vlog", "behind the scenes", "BTS" | Looser pacing, natural sound forward, lower production polish |
| "ad", "campaign", "spot" | Tight (≤30s), hook in first 2s, music bed expected, brand-compliant |
| "explainer", "tutorial", "how-to" | Clear pacing, on-screen text, kinetic typography for key terms |
| "highlight reel", "sizzle", "best of" | Montage pace, music-driven, drop sections at peaks |
| "ceremony", "wedding", "funeral" | Pacing slow, music continuous, captions OFF unless requested |
| No prompt + footage suggests subject | INFER subject from transcript + brand + setting. Don't ask. Audit on return |
| "in <language>" or transcript in non-English | Burn captions in that language; brand voice in that language |
| "for <named team / department>" | Inference = internal-distribution artifact. Hits internal_review variant criteria |
| "we want to share on <platform>" | Use that platform's preset from `delivery-presets.json` |

### Constraint signals

| Brief contains | Inference |
|---|---|
| "before I'm back", "by Friday", "deadline" | Hard deadline. Self-approve strategy. No back-and-forth |
| "top spec", "high quality", "premium" | Color grade applied; loudness normalized; final at delivery res, not preview |
| "draft", "rough", "for review" | Preview-quality OK; can defer mastering. Mark as draft in filename |
| "no time", "quick", "fast turnaround" | Single deliverable, no variants. Skip brand fetch unless trivially fast |
| "budget" mentioned | Stays local — no paid APIs ever (this is also the architectural constraint) |

## The automatic-research pass

When the agent identifies a brand or named subject during inventory:

1. **Save the identification** to `manifest.brand.name` and
   `manifest.brief_intent.brand`.
2. **WebFetch the official press / media page** (try
   `<brand-domain>/media`, `<brand-domain>/press`,
   `<brand-domain>/about/media`, `<brand-domain>/en/media`). Read the
   page for: logo download URL, brand colors (hex), brand voice
   guidelines, social handles.
3. **Save the press URL** to `manifest.brand.official_press_url`. Save
   any retrieved logo to `/work/<id>/brand/logo.<ext>`. Save brand
   colors to `manifest.brand.primary_color` and `secondary_color`.
4. **Match the subject to a persona** in
   `agents/fsh-music-mood-bridge/personas.yaml`. Save persona key to
   `manifest.audience_persona`. The agent picks the closest match;
   when nothing fits, it ADDS a new persona to the yaml with its
   rationale (and records the new persona key in the manifest).
5. **Look up the persona's music criteria** and set
   `manifest.music.mode` (default per the platform preset in
   `delivery-presets.json`).

The agent never asks the user for any of these — they are derived from
the footage + brief. The user audits the `manifest.brief_intent` block
on return.

## The "WHY" rule

For every inference recorded into `manifest.brief_intent`, the agent
writes a one-line WHY. This is non-negotiable. Without WHY, the user
can't audit; with WHY, they can either nod or correct.

Example block, written to `manifest.brief_intent.why`:

```json
{
  "platforms": ["reels-vertical"],
  "platforms_why": "All Canon sources composed vertical without rotation flag, brand=ORLEN is active on Instagram, brief said 'marketing team' — Reels is the closest platform match.",
  "audience": "Petrochemical / heavy industrial B2B",
  "audience_why": "Subject identified as ORLEN Unipetrol pyrolysis pilot, ČR market, branded PPE — matches the B2B-industrial persona in personas.yaml.",
  "delivery_pattern": "internal_review + platform_clean + music_cues",
  "delivery_pattern_why": "Reels platform → marketing adds licensed music in the Instagram UI; internal_review carries the proposed bed for sign-off; platform_clean is the muted upload artifact.",
  "music_mode": "internal-reference",
  "music_mode_why": "Reels preset default; marketing handles final track via IG library."
}
```

## When to ask the user vs when to infer

Default: **infer and record**. The user audits on return. The user is
not the editor; they don't want to be paged.

Exceptions where the agent DOES ask, inline, once:

- The brief itself is contradictory (e.g., "Reels, but make it 4 minutes")
- The footage + brief disagree fundamentally (e.g., brief says "wedding" but
  footage is industrial)
- A brand identification has multiple legitimate matches and the wrong
  one would mean wrong logo + wrong colors in delivery

Even then: phrase the question as "I'm inferring X; correct me if Y" —
not "what should I do?"

## Pitfalls

- **Literal-mode trap.** "Make a marketing video" interpreted as "make
  one video" instead of "make the full marketing kit." Always run the
  three-pass read.
- **Default-persona trap.** Picking a generic "corporate cinematic"
  persona when the subject is clearly B2B-industrial or wedding or
  documentary. Match the persona to the SUBJECT, not to a default.
- **No-WHY trap.** Recording inferences without rationale. The user
  can't roll back what they can't see reasoning for.
- **Skipping brand fetch.** If a logo is visible in any frame, the
  agent must attempt the press-kit fetch. Free metadata that wins the
  client trust.
- **Burying inferences in `project.md` instead of `manifest.brief_intent`.**
  The manifest is the audit surface. project.md is session memory.
  Inferences go in BOTH but the manifest is canonical.
