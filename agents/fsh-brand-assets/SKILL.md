---
name: fsh-brand-assets
description: Pull official brand assets (logos, colors, voice guidelines) from a brand's official press / media page. WebFetch-based, audit-trail preserving. Used during /inventory's automatic-research pass when a brand is identified from the footage. Never uses generic image search.
version: 1.0.0
---

# Brand Asset Retrieval — Official Sources Only

When the agent identifies a brand from footage (visible logo, branded
PPE, name patches, transcript mention), this skill pulls the brand's
official media kit. Used in the `/inventory` automatic-research pass.

> Reference case: smoke test #1 needed a reprompt to pull the ORLEN
> logo. Without this skill, the agent either skipped brand assets or
> grabbed something from Google Images — both fail audit. With this
> skill, the agent reaches the official press page directly and saves
> the URL alongside the asset for provenance.

## Strict default behavior

**Official sources only.** The agent tries, in order:

1. `<brand-domain>/media`
2. `<brand-domain>/press`
3. `<brand-domain>/about/media`
4. `<brand-domain>/en/media` (for non-English primary domains)
5. `<brand-domain>/newsroom`
6. `<brand-domain>/brand-guidelines`
7. `<brand-domain>/about/brand`
8. `<brand-parent-corp-domain>/...` for subsidiary brands (e.g.
   `orlenunipetrol.cz/media` falls back to `orlen.pl/media`)

If none of those resolve, the agent looks for a press contact via the
brand's `/contact` page and files a `Capability` issue (brand-press-page-not-found)
rather than substituting a Google image grab.

**Never use Google Images, Wikipedia, Wikimedia Commons, or third-party
logo aggregators** (logosearch, brandfetch, seeklogo, etc.) as the
canonical source. These can carry outdated or unauthorized variants.

## What to fetch

For each identified brand, save to `/work/<id>/brand/`:

| File | Source | Notes |
|---|---|---|
| `logo.svg` (or `.png` fallback) | Press kit's primary download | Prefer SVG; fall back to highest-res PNG |
| `logo_mono.svg` | If brand has a single-color version | Useful for overlays on busy footage |
| `colors.json` | Brand guidelines page | `{primary: "#ED1C24", secondary: "#000000", neutrals: [...]}` |
| `typography.json` | Brand guidelines page | `{primary_face: "...", secondary_face: "...", fallback: "..."}` |
| `voice.md` | Brand guidelines page | Tone keywords, do/don't phrases |
| `source.md` | Auto-generated | URL of every fetch + ISO timestamp |

The `source.md` audit file is non-negotiable. It lists every URL the
agent visited, what it pulled from each, and when. Without it, the
marketing team can't verify the asset provenance.

## Skill output

Updates `manifest.brand` with the structured result:

```json
{
  "brand": {
    "name": "ORLEN Unipetrol",
    "parent_brand": "ORLEN",
    "official_press_url": "https://www.unipetrol.cz/en/media",
    "logo_path": "/work/<id>/brand/logo.svg",
    "logo_mono_path": "/work/<id>/brand/logo_mono.svg",
    "primary_color": "#ED1C24",
    "secondary_color": "#000000",
    "voice": "industrial / technical / sustainability-forward",
    "source_audit": "/work/<id>/brand/source.md"
  }
}
```

## Architecture

The skill is a single Python module
`agents/fsh-brand-assets/fetch.py` that exposes:

```python
def fetch_brand(brand_name: str, hint_domain: str = None, work_dir: Path = None) -> BrandKit:
    """Resolve the brand's official press URL, download the assets,
    populate /work/<id>/brand/, return a BrandKit dataclass.

    Tries common press-page URL patterns. Uses WebFetch (claude tool)
    to read the page, then a follow-up WebFetch per asset URL.

    Saves source.md as it goes — every URL visited, every asset
    pulled, every timestamp.
    """
```

## When the autonomous fetch is blocked

Two reasons it can happen:

1. **Classifier denial** — the agent's WebFetch / Bash tools refuse the
   fetch even after rephrasing. Common in early-session sandboxes.
2. **Official press page not resolvable** — none of the common URL
   patterns return a usable kit.

In either case, **do not** substitute a Google grab, a Wikimedia
upload, or a third-party logo aggregator. Instead, generate a drop-in
scaffold so the user can supply the official asset in one file move:

```bash
/opt/claude-config/tools/dropin-scaffold "<slug>" logo \
  --sources "<brand-domain>/media,<brand-domain>/press,<brand-parent-corp>/about/media" \
  --notes "Brand identified as <name>. Logo overlay used on close card last 1.5s."
```

That creates:
- `/assets/<id>/branding/README.md` listing the candidate URLs + drop path
- `/work/<slug>/edit/add_logo.py` merge script template
- `manifest.logo.pending_dropin = true`

The agent then continues with everything else (renders all variants
the logo isn't required for; bakes the merge step so a single command
applies the logo when the file lands).

Also file a `Capability` issue:

```markdown
---
type: Capability
status: investigating
brand: <inferred brand name>
hint_domain: <inferred domain or null>
why: official press page not autonomously fetchable
---

Tried:
- <url-1>: <result>
- <url-2>: <result>
...

Drop-in scaffold staged at /assets/<id>/branding/. Two unblock paths:
authorize a specific URL, or drop the file directly.
```

See `/docs/DROPIN_SCAFFOLD_PATTERN.md` for the canonical pattern.

## Cross-references

- `/docs/BRIEF_INTERPRETATION.md` — the automatic-research pass calls
  this skill during /inventory
- `agents/fsh-music-mood-bridge/personas.yaml` — persona's
  `brand_voice` field aligns with this skill's `voice.md`
- `agents/brand-guidelines/` (Anthropic skills) — broader brand-intake
  guidance, complementary

## Pitfalls

- **Logo at wrong aspect.** Press kits often ship multiple variants
  (horizontal lockup, square, monogram). Pick the right one for the
  overlay context: square for vertical Reels lower-third, horizontal
  for landscape end-card.
- **Color profile mismatch.** Brand guidelines list sRGB / CMYK
  variants. Always pick sRGB for video.
- **Trademark / usage restrictions.** Some press kits restrict use to
  editorial vs commercial. Save the usage terms link in `source.md`.
- **Cached / outdated assets.** If `source.md` shows the last fetch
  was > 90 days ago, re-fetch before delivery.
